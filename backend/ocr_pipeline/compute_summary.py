"""
Script de consolidação estatística e extração de evidências da execução em lote dos 559 alvos.
Lê batch_559_progress.jsonl e produz:
  - Estatísticas de tempo e telemetria de memória
  - Distribuição de confiança antes vs depois
  - Taxa de resolução para os limiares de homologação
  - Extração literal dos 3 casos representativos (fácil, médio, pior caso)
"""
import json
from pathlib import Path

PROGRESS_JSONL = Path(__file__).resolve().parent / "batch_559_progress.jsonl"
SUMMARY_OUTPUT = Path(__file__).resolve().parent / "batch_559_summary.json"

def analyze_progress():
    if not PROGRESS_JSONL.exists():
        print("Arquivo de progresso não encontrado.")
        return

    records = []
    with open(PROGRESS_JSONL, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except Exception:
                    pass

    total = len(records)
    if total == 0:
        print("Nenhum registro encontrado.")
        return

    times = [r["elapsed_seconds"] for r in records]
    confs_before = [r["confidence_before"] for r in records if r["confidence_before"] is not None]
    confs_after = [r["confidence_after"] for r in records]
    deltas = [r["delta_confidence"] for r in records if r["delta_confidence"] is not None]
    rss_list = [r["process_rss_mb"] for r in records if r.get("process_rss_mb") is not None]
    avail_list = [r["system_avail_mb"] for r in records if r.get("system_avail_mb") is not None]

    # Distribuição de confiança
    def bucket(val):
        if val < 50.0:
            return "< 50.0 (Crítico)"
        elif val < 70.0:
            return "50.0 - 69.9 (Baixo)"
        elif val < 85.0:
            return "70.0 - 84.9 (Moderado)"
        elif val < 94.0:
            return "85.0 - 93.9 (Bom)"
        else:
            return ">= 94.0 (Excelente)"

    dist_before = {}
    for c in confs_before:
        b = bucket(c)
        dist_before[b] = dist_before.get(b, 0) + 1

    dist_after = {}
    for c in confs_after:
        b = bucket(c)
        dist_after[b] = dist_after.get(b, 0) + 1

    # Resolução
    above_85_after = sum(1 for c in confs_after if c >= 85.0)
    above_90_after = sum(1 for c in confs_after if c >= 90.0)
    above_94_after = sum(1 for c in confs_after if c >= 94.0)

    summary = {
        "total_processed": total,
        "total_time_seconds": round(sum(times), 2),
        "total_time_minutes": round(sum(times) / 60.0, 2),
        "mean_time_per_page": round(sum(times) / total, 2),
        "min_time_per_page": min(times),
        "max_time_per_page": max(times),
        "mean_confidence_before": round(sum(confs_before) / len(confs_before), 2) if confs_before else 0.0,
        "mean_confidence_after": round(sum(confs_after) / len(confs_after), 2),
        "mean_delta_confidence": round(sum(deltas) / len(deltas), 2) if deltas else 0.0,
        "max_rss_mb": max(rss_list) if rss_list else 0.0,
        "min_avail_ram_mb": min(avail_list) if avail_list else 0.0,
        "distribution_before": dist_before,
        "distribution_after": dist_after,
        "resolution": {
            "above_85": {"count": above_85_after, "pct": round(above_85_after / total * 100, 1)},
            "above_90": {"count": above_90_after, "pct": round(above_90_after / total * 100, 1)},
            "above_94": {"count": above_94_after, "pct": round(above_94_after / total * 100, 1)},
        },
        "engines_used_breakdown": {},
        "sanity_status_breakdown": {}
    }

    for r in records:
        eng = r.get("engine_used", "unknown")
        summary["engines_used_breakdown"][eng] = summary["engines_used_breakdown"].get(eng, 0) + 1
        san = r.get("sanity_status", "unknown")
        summary["sanity_status_breakdown"][san] = summary["sanity_status_breakdown"].get(san, 0) + 1

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    with open(SUMMARY_OUTPUT, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    analyze_progress()
