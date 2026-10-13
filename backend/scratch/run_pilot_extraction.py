import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pedagogico.filologia.progressive_extractor import ProgressiveNavarroExtractor
from pedagogico.filologia.review_queue import PhilologicalReviewQueue


extractor = ProgressiveNavarroExtractor()
report = extractor.process_batch(start_page=30, end_page=35, batch_id="BATCH-PILOT-01")

print("=== RELATÓRIO DO LOTE PILOTO DE EXTRAÇÃO ===")
print(f"Batch ID: {report.batch_id}")
print(f"Páginas processadas: {report.pages_processed}")
print(f"Páginas com rotação invertida detectada: {report.orientation_corrected_pages}")
print(f"Total de candidatos extraídos: {report.candidates_extracted_count}")
print(f"Lemas únicos neste lote: {report.unique_lemmas_count}")
print(f"Duplicatas detectadas: {report.duplicates_detected_count}")
print(f"Candidatos com revisão humana urgente: {report.flagged_for_human_review_count}")
print(f"Duração do lote: {report.total_duration_seconds:.2f}s")

queue = PhilologicalReviewQueue(extractor=extractor)
pending = queue.list_pending(limit=5)
print(f"\nTotal pendente na fila: {queue.count_pending()}")
for p in pending:
    c_id = p["id"]
    lema = p["lema_original"]
    cls = p["classe_gramatical"]
    req = p["ocr_evidence"]["requires_human_review"]
    print(f"  [{c_id}] {lema} ({cls}) - requer_revisao_urgente={req}")
