import json
from pathlib import Path

base = Path(__file__).resolve().parent.parent / "pedagogico"
manifestos = base / "manifestos"

lexicon_by_var = {"tupi_antigo": {}, "tupi_revitalizado": {}}

for var in ["tupi_antigo", "tupi_revitalizado"]:
    for ch in range(1, 21):
        mf = manifestos / f"manifesto_{var}_cap{ch:02d}.json"
        if mf.exists():
            data = json.load(open(mf, encoding="utf-8"))
            lexicon_by_var[var][ch] = data.get("itens_ensinados", [])

header = '''"""
TupiLingo — Banco de Dados Léxico e Morfológico Autenticado do RAG
Contém o mapeamento dos 20 capítulos para as 2 variantes canônicas:
  1. tupi_antigo (Quinhentista / Clássico - Eduardo Navarro USP)
  2. tupi_revitalizado (Método Moderno / Revitalização - Eduardo Navarro USP)

Todos os itens possuem proveniência rastreável a chunks do vector_store.db.
"""

from typing import Dict, Any, List

# Estrutura: LEXICON_BY_VARIANT_CHAPTER[variant][chapter_num] = list of items
LEXICON_BY_VARIANT_CHAPTER: Dict[str, Dict[int, List[Dict[str, Any]]]] = '''

lex_file = base / "lexicon_data.py"
with open(lex_file, "w", encoding="utf-8") as f:
    f.write(header)
    f.write(json.dumps(lexicon_by_var, indent=4, ensure_ascii=False))
    f.write("\n")

print("lexicon_data.py gerado com sucesso!")
