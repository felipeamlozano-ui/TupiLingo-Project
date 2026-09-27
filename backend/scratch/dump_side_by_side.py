import json

with open("scratch/real_pages_v3_results.json", "r", encoding="utf-8") as f:
    results = json.load(f)

res_map = {(r["pdf"], r["page"]): r for r in results}

# 1. Ayrosa Página 1
ayr_p1 = res_map.get(("Ayrosa", 1), {})
# 2. Dicionário Página 8 (atenção)
dic_p8 = res_map.get(("Dicionario", 8), {})
# 3. Dicionário Página 11 (mediano)
dic_p11 = res_map.get(("Dicionario", 11), {})

print("Ayrosa p.1 v3 text len:", len(ayr_p1.get("v3_sample", "")))
print("Dicionario p.8 v3 text len:", len(dic_p8.get("v3_sample", "")))
print("Dicionario p.11 v3 text len:", len(dic_p11.get("v3_sample", "")))
