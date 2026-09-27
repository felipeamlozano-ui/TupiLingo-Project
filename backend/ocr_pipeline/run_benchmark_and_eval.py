"""
Benchmark e Avaliação Experimental da Fase 0 e Fase 1 sobre o Corpus Real do TupiLingo.
Aplica a esteira completa sobre páginas representativas dos PDFs escaneados problemáticos:
  - Dicionário Tupi.pdf
  - Simpson_1955_GramaticaLinguaBrasileira.pdf
  - survey-report-8.07-moore-etal.pdf
  - Ribeiro_1988_DicionarioDoArtesanatoIndigena.pdf

Gera evidências brutas de antes/depois, tempos em CPU, taxas de concordância e
taxa de resolução para embasar o ponto de decisão da Fase 2.
"""
import json
import sqlite3
import sys
import time
from pathlib import Path

import pypdfium2 as pdfium

# Adiciona backend ao sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from ocr_pipeline.models import PageType
from ocr_pipeline.pipeline_orchestrator import PipelineOrchestrator

PDFS_DIR = BACKEND_DIR / "pdfs"
DB_PATH = BACKEND_DIR / "vector_store.db"
TUPI_WORDS_FILE = BACKEND_DIR / "tupi_user_words.txt"
LEXICON_DATA_FILE = BACKEND_DIR / "pedagogico" / "lexicon_data.py"
OUTPUT_REPORT = BACKEND_DIR / "ocr_pipeline" / "benchmark_results.json"

# Páginas de teste cobrindo início, meio e seções densas dos PDFs escaneados
TEST_TARGETS = [
    {"pdf": "Dicionário Tupi.pdf", "pages": [15, 30, 60, 100, 150, 220]},
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "pages": [10, 35, 70]},
    {"pdf": "survey-report-8.07-moore-etal.pdf", "pages": [8, 18]},
    {"pdf": "Ribeiro_1988_DicionarioDoArtesanatoIndigena.pdf", "pages": [25, 80]}
]

def load_historical_page_conf(db_path: Path, filename: str, page_num: int):
    """Recupera a confiança histórica do OCR e flag precisa_revisao do banco."""
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    cursor.execute("""
        SELECT metadata, confianca, precisa_revisao 
        FROM documents 
        WHERE metadata LIKE ?
    """, (f'%"{filename}"%',))
    rows = cursor.fetchall()
    conn.close()

    confs = []
    precisa_rev = 0
    for meta_str, conf, rev in rows:
        try:
            meta = json.loads(meta_str)
            if meta.get("page") == page_num:
                if rev == 1:
                    precisa_rev = 1
                ocr_c = meta.get("ocr_conf_mean")
                if ocr_c is not None:
                    confs.append(float(ocr_c))
        except Exception:
            continue

    avg_conf = float(sum(confs) / len(confs)) if confs else None
    return avg_conf, (precisa_rev == 1)

def run_benchmark():
    print("=" * 80)
    print("INICIANDO BENCHMARK DA FASE 0 & FASE 1 — TUPILINGO OCR PIPELINE")
    print("=" * 80)

    orchestrator = PipelineOrchestrator(
        tupi_words_path=TUPI_WORDS_FILE,
        lexicon_data_path=LEXICON_DATA_FILE,
        cpu_threads=4
    )

    results = []
    total_t0 = time.time()

    for target in TEST_TARGETS:
        fname = target["pdf"]
        pdf_path = PDFS_DIR / fname
        if not pdf_path.exists():
            print(f"[PULANDO] Arquivo não encontrado: {fname}")
            continue

        print(f"\n>>> Processando PDF: {fname}")
        pdf = pdfium.PdfDocument(str(pdf_path))

        for p_num in target["pages"]:
            page_idx = p_num - 1
            if page_idx < 0 or page_idx >= len(pdf):
                continue

            page = pdf[page_idx]
            # Render a 300 DPI
            pil_img = page.render(scale=300.0 / 72.0).to_pil()

            # Buscar histórico
            hist_conf, hist_rev = load_historical_page_conf(DB_PATH, fname, p_num)

            t_page0 = time.time()
            # Força execução da Fase 1 para teste de estresse e benchmark comparativo
            profile, ocr_res, chunks, audit = orchestrator.process_page(
                pil_img=pil_img,
                filename=fname,
                page_num=p_num,
                historical_ocr_conf=hist_conf,
                precisa_revisao_hist=hist_rev,
                page_type=PageType.SCAN,
                force_phase1=True
            )
            elapsed_page = time.time() - t_page0

            record = {
                "pdf": fname,
                "page": p_num,
                "dimensions": f"{profile.width}x{profile.height}",
                "columns_detected": profile.num_columns,
                "has_bleed_through": profile.has_bleed_through,
                "blur_laplacian": round(profile.blur_laplacian, 1),
                "contrast_rms": round(profile.contrast_rms, 1),
                "skew_angle": round(profile.skew_angle, 2),
                "quality_score_fase0": profile.quality_score,
                "routing_decision": profile.routing_decision.value,
                "confidence_before": round(hist_conf, 1) if hist_conf else None,
                "confidence_after": audit.confidence_after,
                "delta_confidence": round(audit.confidence_after - (hist_conf or 0.0), 1) if hist_conf else None,
                "engine_used": audit.engine_used,
                "agreement_rate": audit.agreement_rate,
                "lexical_corrections_count": audit.lexical_corrections_count,
                "sample_corrections": ocr_res.corrections_applied[:3] if ocr_res else [],
                "chunks_generated": len(chunks),
                "dictionary_entries_found": audit.dictionary_entries_found,
                "needs_review": audit.needs_manual_review,
                "sanity_status": audit.sanity_status,
                "elapsed_seconds": round(elapsed_page, 2),
                "sample_text_head": ocr_res.text_cleaned[:250].replace("\n", " ") if ocr_res else ""
            }
            results.append(record)

            print(f"  Pág {p_num:3d} | Score F0: {profile.quality_score:5.1f} ({profile.routing_decision.value}) "
                  f"| Conf: {hist_conf or 0.0:5.1f} -> {audit.confidence_after:5.1f} "
                  f"| Colunas: {profile.num_columns} | Bleed: {profile.has_bleed_through} "
                  f"| Chunks: {len(chunks):2d} | Tempo: {elapsed_page:5.2f}s")

    total_time = time.time() - total_t0
    print("\n" + "=" * 80)
    print("CONSOLIDAÇÃO DOS RESULTADOS DO BENCHMARK")
    print("=" * 80)
    print(f"Total de páginas avaliadas: {len(results)}")
    print(f"Tempo total de execução em CPU (4 threads): {total_time:.2f}s (Média: {total_time/max(len(results),1):.2f}s/pág)")

    confs_before = [r["confidence_before"] for r in results if r["confidence_before"] is not None]
    confs_after = [r["confidence_after"] for r in results]
    avg_before = sum(confs_before) / len(confs_before) if confs_before else 0.0
    avg_after = sum(confs_after) / len(confs_after) if confs_after else 0.0

    pages_below_90_before = sum(1 for c in confs_before if c < 90.0)
    pages_below_90_after = sum(1 for c in confs_after if c < 90.0)
    pages_below_85_after = sum(1 for c in confs_after if c < 85.0)

    print(f"Confiança média OCR: {avg_before:.2f}% (antes) -> {avg_after:.2f}% (depois)")
    print(f"Ganho médio de confiança: +{avg_after - avg_before:.2f}%")
    print(f"Páginas com Confiança < 90%: {pages_below_90_before}/{len(confs_before)} (antes) -> {pages_below_90_after}/{len(results)} (depois)")
    print(f"Páginas com Confiança < 85% (Fila de Revisão): {pages_below_85_after}/{len(results)}")

    summary = {
        "total_pages_tested": len(results),
        "total_elapsed_seconds": round(total_time, 2),
        "mean_seconds_per_page": round(total_time / max(len(results), 1), 2),
        "mean_confidence_before": round(avg_before, 2),
        "mean_confidence_after": round(avg_after, 2),
        "mean_delta_confidence": round(avg_after - avg_before, 2),
        "pages_below_90_before": pages_below_90_before,
        "pages_below_90_after": pages_below_90_after,
        "pages_below_85_after": pages_below_85_after,
        "resolution_rate_above_90": round((len(results) - pages_below_90_after) / max(len(results), 1) * 100, 2),
        "detailed_results": results
    }

    with open(OUTPUT_REPORT, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    print(f"\nRelatório completo salvo em: {OUTPUT_REPORT}")

if __name__ == "__main__":
    run_benchmark()
