import logging

from app.ai.rag_service import get_db
from django.core.management.base import BaseCommand
from django.db import close_old_connections, connection

logger = logging.getLogger("nivelamento.etl")

class Command(BaseCommand):
    help = (
        "Localiza no Supabase e no SQLite local todos os chunks marcados como 'Desconhecido' "
        "devido ao esgotamento de cota anterior, limpa do Supabase e reseta category_extracted = 0 no SQLite."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Apenas exibe os registros que seriam limpos sem executar a alteração.',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        self.stdout.write(self.style.NOTICE(
            f"Iniciando rotina de limpeza de chunks corrompidos (Dry Run: {dry_run})..."
        ))

        close_old_connections()
        with connection.cursor() as cursor:
            # 1. Busca todos os chunk_ids marcados como Desconhecido no Supabase
            cursor.execute("""
                SELECT chunk_id, SUBSTRING(chunk_id, 1, 8) as pfx
                FROM rag_document_categories
                WHERE categoria = 'Desconhecido'
            """)
            rows = cursor.fetchall()
            chunk_ids = [r[0] for r in rows]

            # Contagem por prefixo/arquivo
            prefix_counts = {}
            for _, pfx in rows:
                prefix_counts[pfx] = prefix_counts.get(pfx, 0) + 1

        self.stdout.write(self.style.WARNING(
            f"Encontrados {len(chunk_ids)} registros marcados como 'Desconhecido' no Supabase:"
        ))
        for pfx, count in sorted(prefix_counts.items(), key=lambda x: x[1], reverse=True):
            self.stdout.write(f"  - Prefixo {pfx}: {count} chunks")

        if not chunk_ids:
            self.stdout.write(self.style.SUCCESS("Nenhum chunk 'Desconhecido' encontrado para limpeza."))
            return

        if dry_run:
            self.stdout.write(self.style.NOTICE("Modo Dry Run ativado. Nenhuma alteração persistida."))
            return

        # 2. Deleta os registros com categoria = 'Desconhecido' do Supabase
        self.stdout.write(self.style.NOTICE("Removendo registros inválidos da tabela rag_document_categories no Supabase..."))
        close_old_connections()
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM rag_document_categories WHERE categoria = 'Desconhecido'")
            removidos_supabase = cursor.rowcount
        connection.close()

        self.stdout.write(self.style.SUCCESS(
            f"[OK] {removidos_supabase} registros removidos do Supabase com sucesso."
        ))

        # 3. Reseta status no SQLite local (category_extracted = 0)
        self.stdout.write(self.style.NOTICE("Resetando status no SQLite local (vector_store.db) para category_extracted = 0..."))
        vector_db = get_db()
        with vector_db._connect() as conn:
            # Executa o reset em lotes para performance
            batch_size = 500
            total_resetados = 0
            for i in range(0, len(chunk_ids), batch_size):
                lote = [(cid,) for cid in chunk_ids[i:i + batch_size]]
                conn.executemany("UPDATE documents SET category_extracted = 0 WHERE id = ?", lote)
                total_resetados += len(lote)
            conn.commit()

            # Consulta o novo estado do SQLite
            total_pendentes = conn.execute("SELECT count(*) FROM documents WHERE category_extracted = 0").fetchone()[0]
            total_extraidos = conn.execute("SELECT count(*) FROM documents WHERE category_extracted = 1").fetchone()[0]
            total_geral = conn.execute("SELECT count(*) FROM documents").fetchone()[0]

        self.stdout.write(self.style.SUCCESS(
            f"[OK] {total_resetados} chunks resetados com sucesso no SQLite local."
        ))
        self.stdout.write(self.style.SUCCESS(
            f"Estado atual do SQLite: Total={total_geral}, Pendentes={total_pendentes}, Extraídos={total_extraidos}."
        ))
        self.stdout.write(self.style.SUCCESS(
            "Limpeza concluída com sucesso! Os chunks estão prontos para reprocessamento na nova esteira."
        ))

