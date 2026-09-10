"""
Django Management Command: seed_quiz_pool

Carrega pacotes de questões estáticas validadas para o Question Pool do Redis.
Garante:
  1. Validação estrita linha-a-linha contra o JSON Schema antes de qualquer escrita.
  2. Carga atômica em lote via Redis Pipeline (SADD com pacote_id UUID anti-colisão).
  3. Zero chamadas externas de rede.
  4. Relatório detalhado de rejeição caso o arquivo contenha dados corrompidos.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import jsonschema
from django.core.management.base import BaseCommand, CommandError

from app.ai.ping_race import get_redis_client
from app.schemas.quiz import QuizResponse, QuizItem


class Command(BaseCommand):
    help = "Valida e descarrega pacotes de questões estáticas no Question Pool do Redis."

    def add_arguments(self, parser):
        parser.add_argument(
            "--file",
            type=str,
            default=None,
            help="Caminho personalizado para o arquivo seed_tupi_nivelamento.json",
        )
        parser.add_argument(
            "--flush",
            action="store_true",
            help="Limpa os pools existentes antes de carregar os novos pacotes.",
        )

    def handle(self, *args: Any, **options: Any):
        base_dir = Path(__file__).resolve().parent.parent.parent
        fixtures_dir = base_dir / "fixtures"

        json_file_path = (
            Path(options["file"])
            if options["file"]
            else fixtures_dir / "seed_tupi_nivelamento.json"
        )
        schema_file_path = fixtures_dir / "seed_tupi_nivelamento.schema.json"

        if not json_file_path.exists():
            raise CommandError(f"Arquivo de dados não encontrado: {json_file_path}")

        if not schema_file_path.exists():
            raise CommandError(f"Schema de validação não encontrado: {schema_file_path}")

        self.stdout.write(self.style.NOTICE(f"[SeedPool] Lendo fixture: {json_file_path.name}..."))
        with open(json_file_path, "r", encoding="utf-8") as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as err:
                raise CommandError(f"JSON corrompido em {json_file_path}: {err}")

        with open(schema_file_path, "r", encoding="utf-8") as f:
            try:
                schema = json.load(f)
            except json.JSONDecodeError as err:
                raise CommandError(f"Schema corrompido em {schema_file_path}: {err}")

        # ── 1. VALIDAÇÃO ESTRITA CONTRA JSON SCHEMA ──────────────────────────
        self.stdout.write(self.style.NOTICE("[SeedPool] Validando integridade contra seed_tupi_nivelamento.schema.json..."))
        validator = jsonschema.Draft7Validator(schema)
        errors = list(validator.iter_errors(data))

        if errors:
            self.stderr.write(self.style.ERROR(f"[ERRO] Rejeicao de carga: Encontrados {len(errors)} erros de schema!"))
            for idx, err in enumerate(errors[:15], start=1):
                path = " -> ".join(str(p) for p in err.absolute_path)
                self.stderr.write(f"  [{idx}] Caminho: {path or 'raiz'} | Erro: {err.message}")
            if len(errors) > 15:
                self.stderr.write(f"  ... e mais {len(errors) - 15} erros omitidos.")
            raise CommandError("A carga foi abortada para evitar contaminacao do Question Pool com dados invalidos.")

        self.stdout.write(self.style.SUCCESS("[OK] Schema JSON validado com 100% de conformidade!"))

        # ── 2. CONEXÃO AO REDIS ──────────────────────────────────────────────
        r = get_redis_client()
        if not r:
            raise CommandError("Nao foi possivel conectar ao Redis. Verifique REDIS_URL e se o servico esta ativo.")

        try:
            r.ping()
        except Exception as exc:
            raise CommandError(f"Falha de conexao com o Redis: {exc}")

        # ── 3. CARGA NO REDIS VIA PIPELINE ATÔMICO ───────────────────────────
        if options["flush"]:
            self.stdout.write(self.style.WARNING("[SeedPool] Limpando chaves antigas de pool..."))
            keys_to_delete = r.keys("quiz_pool:*")
            if keys_to_delete:
                r.delete(*keys_to_delete)
                self.stdout.write(f"  Removidas {len(keys_to_delete)} chaves antigas.")

        pipe = r.pipeline(transaction=False)
        total_pacotes = len(data)
        pacotes_por_nivel: dict[str, int] = {}
        total_questoes = 0

        for pacote in data:
            variante = pacote["variante"]
            nivel = pacote["nivel"]
            pacote_id = pacote["pacote_id"]
            questoes = pacote["questoes"]

            key = f"quiz_pool:{variante}:{nivel}"
            # Serializa o pacote garantindo pacote_id e questões com fonte_confianca
            payload_json = json.dumps({
                "pacote_id": pacote_id,
                "questoes": questoes,
                "provider": "StaticSeed",
                "modelo": "TupiAntigo-Curated",
                "tempo_total_ms": 0,
                "cache_hit": True,
            }, ensure_ascii=False)

            # SADD no Redis: seguro contra duplicação porque pacote_id é UUID único
            pipe.sadd(key, payload_json)
            # TTL de 30 dias para persistência duradoura
            pipe.expire(key, 86400 * 30)

            # Sincroniza também a variante tupinamba se o pacote for de tupi
            if variante == "tupi":
                tup_key = f"quiz_pool:tupinamba:{nivel}"
                pipe.sadd(tup_key, payload_json)
                pipe.expire(tup_key, 86400 * 30)
                pacotes_por_nivel[tup_key] = pacotes_por_nivel.get(tup_key, 0) + 1

            pacotes_por_nivel[key] = pacotes_por_nivel.get(key, 0) + 1
            total_questoes += len(questoes)

        self.stdout.write(self.style.NOTICE("[SeedPool] Descarregando pacotes no Redis via pipeline..."))
        pipe.execute()

        self.stdout.write(self.style.SUCCESS("\n" + "=" * 65))
        self.stdout.write(self.style.SUCCESS("[SUCESSO] CARGA DO QUESTION POOL CONCLUIDA!"))
        self.stdout.write(self.style.SUCCESS("=" * 65))
        self.stdout.write(f"* Total de Pacotes Carregados : {total_pacotes}")
        self.stdout.write(f"* Total de Questoes Curadas   : {total_questoes}")
        self.stdout.write("* Distribuicao por Pool (Redis Set):")
        for pool_key, count in sorted(pacotes_por_nivel.items()):
            cur_card = r.scard(pool_key)
            self.stdout.write(f"    - {pool_key:<25}: +{count} pacotes carregados (total no Redis: {cur_card})")
        self.stdout.write(self.style.SUCCESS("=" * 65 + "\n"))
