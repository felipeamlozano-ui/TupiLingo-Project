import json

with open("scratch/real_pages_v3_results.json", "r", encoding="utf-8") as f:
    data = json.load(f)

for r in data:
    if (r["pdf"] == "Ayrosa" and r["page"] in [1, 2]) or (
        r["pdf"] == "Dicionario" and r["page"] in [6, 11]
    ):
        pname = r["pdf"]
        pnum = r["page"]
        c = r["components"]
        print(f"=== {pname} Página {pnum} ===")
        print(f"  OCR Bruto (c_ocr)       : {c['c_ocr']:>6.2f} (peso 0.45 -> {c['weighted_ocr']:>5.2f})")
        print(f"  Visual / Layout (c_vis) : {c['c_vis']:>6.2f} (peso 0.20 -> {c['weighted_vis']:>5.2f})")
        print(f"  Léxico / Morfol (c_lex) : {c['c_lex']:>6.2f} (peso 0.20 -> {c['weighted_lex']:>5.2f})")
        print(f"  RAG Acervo Real (c_rag) : {c['c_rag']:>6.2f} (peso 0.15 -> {c['weighted_rag']:>5.2f})")
        print(f"  -> Fused Raw            : {c['fused_raw']:>6.2f}")
        print(
            f"  -> Confiança Final v3.0 : {r['v3_conf']:>6.2f} (OCR Bruto era {r['raw_conf']:.2f}, Antigo era {r['old_conf']:.2f})\n"
        )
