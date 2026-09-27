import json
import sqlite3
import numpy as np
from pathlib import Path
from django.core.management.base import BaseCommand
from app.ai.ping_race import PingRaceRouter
from app.core.config import settings

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent.parent
DB_PATH = BACKEND_DIR / "vector_store.db"

class Command(BaseCommand):
    help = "Exibe métricas de observabilidade do RAG, OCR, qualidade de chunks e telemetria de Circuit Breakers."

    def add_arguments(self, parser):
        parser.add_argument(
            "--json",
            action="store_true",
            help="Exporta as métricas em formato JSON estruturado.",
        )

    def handle(self, *args, **options):
        as_json = options["json"]

        if not DB_PATH.exists():
            self.stdout.write(self.style.ERROR(f"Banco vector_store.db não encontrado em {DB_PATH}"))
            return

        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()

        # 1. Total de chunks
        cursor.execute("SELECT COUNT(*) FROM documents")
        total_chunks = cursor.fetchone()[0]

        # 2. Status de revisão e método de classificação
        cursor.execute("""
            SELECT 
                COALESCE(precisa_revisao, 0) as rev,
                COALESCE(metodo_classificacao, 'desconhecido') as met,
                COUNT(*)
            FROM documents
            GROUP BY rev, met
        """)
        revisao_stats = cursor.fetchall()

        # 3. Distribuição de categorias
        cursor.execute("""
            SELECT COALESCE(categoria, 'Não Classificado') as cat, COUNT(*)
            FROM documents
            GROUP BY cat
            ORDER BY COUNT(*) DESC
        """)
        cat_stats = dict(cursor.fetchall())

        # 4. Distribuição de confiança e métodos de extração em metadata
        cursor.execute("SELECT metadata, precisa_revisao, confianca FROM documents WHERE metadata IS NOT NULL")
        rows = cursor.fetchall()

        ocr_confidences = []
        metodos_extracao = {"digital_text": 0, "ocr": 0, "legado_sem_meta": 0}
        sanity_motivos = {}
        chunks_fila_revisao = 0

        for meta_str, precisa_rev, conf in rows:
            if precisa_rev == 1:
                chunks_fila_revisao += 1
            try:
                meta = json.loads(meta_str) if meta_str else {}
            except Exception:
                meta = {}

            met_ext = meta.get("metodo_extracao")
            if met_ext in ("ocr", "ocr_low_conf"):
                metodos_extracao["ocr"] += 1
                c_mean = meta.get("ocr_conf_mean")
                if c_mean is not None:
                    ocr_confidences.append(float(c_mean))
            elif met_ext == "digital_text":
                metodos_extracao["digital_text"] += 1
            else:
                metodos_extracao["legado_sem_meta"] += 1

            s_reason = meta.get("sanity_reason")
            if s_reason and s_reason != "valido":
                sanity_motivos[s_reason] = sanity_motivos.get(s_reason, 0) + 1

        conn.close()

        # Cálculo de estatísticas de confiança OCR
        ocr_stats = {}
        if ocr_confidences:
            arr = np.array(ocr_confidences)
            ocr_stats = {
                "amostras_ocr": len(ocr_confidences),
                "media": round(float(np.mean(arr)), 2),
                "desvio_padrao": round(float(np.std(arr)), 2),
                "min": round(float(np.min(arr)), 2),
                "p25": round(float(np.percentile(arr, 25)), 2),
                "mediana_p50": round(float(np.median(arr)), 2),
                "p75": round(float(np.percentile(arr, 75)), 2),
                "max": round(float(np.max(arr)), 2),
            }
        else:
            ocr_stats = {"amostras_ocr": 0, "msg": "Nenhum chunk com métrica de OCR registrado ainda."}

        # 5. Métricas do Circuit Breaker em tempo real
        circuit_metrics = PingRaceRouter.get_circuit_metrics()

        payload = {
            "total_chunks": total_chunks,
            "metodos_extracao": metodos_extracao,
            "fila_revisao": {
                "total_chunks_em_revisao": chunks_fila_revisao,
                "percentual_base": round((chunks_fila_revisao / total_chunks * 100), 2) if total_chunks else 0.0,
                "motivos_sanidade": sanity_motivos,
            },
            "distribuicao_confianca_ocr": ocr_stats,
            "distribuicao_categorias": cat_stats,
            "circuit_breakers": circuit_metrics,
        }

        if as_json:
            self.stdout.write(json.dumps(payload, indent=2, ensure_ascii=False))
            return

        self.stdout.write(self.style.SUCCESS("\n" + "=" * 70))
        self.stdout.write(self.style.SUCCESS("  PAINEL DE OBSERVABILIDADE: RAG, OCR E CIRCUIT BREAKERS"))
        self.stdout.write(self.style.SUCCESS("=" * 70))
        self.stdout.write(f"Total de chunks no vector_store.db: {total_chunks}")
        self.stdout.write(f"Extracao: Digital={metodos_extracao['digital_text']} | OCR={metodos_extracao['ocr']} | Legado={metodos_extracao['legado_sem_meta']}")
        
        self.stdout.write(self.style.NOTICE(f"\n[FILA DE REVISAO] Chunks sinalizados (precisa_revisao=1): {chunks_fila_revisao} ({payload['fila_revisao']['percentual_base']}%)"))
        if sanity_motivos:
            self.stdout.write("  Motivos de rejeicao/sinalizacao de sanidade:")
            for mot, cnt in sanity_motivos.items():
                self.stdout.write(f"    - {mot}: {cnt}")

        self.stdout.write(self.style.NOTICE("\n[OCR CONFIDENCIA] Distribuicao:"))
        for k, v in ocr_stats.items():
            self.stdout.write(f"  - {k}: {v}")

        self.stdout.write(self.style.NOTICE("\n[CATEGORIAS] Distribuicao:"))
        for cat, cnt in cat_stats.items():
            self.stdout.write(f"  - {cat}: {cnt}")

        self.stdout.write(self.style.NOTICE("\n[CIRCUIT BREAKERS] Telemetria:"))
        self.stdout.write(json.dumps(circuit_metrics, indent=2, ensure_ascii=False))
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 70 + "\n"))
