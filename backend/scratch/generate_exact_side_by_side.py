import sys
import json
import sqlite3
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from ocr_pipeline.lexical_engine.forensic_lexicon import ForensicLexicalEngine

lexical_engine = ForensicLexicalEngine(
    tupi_vocab_path=BACKEND_DIR / "tupi_user_words.txt",
    lexicon_data_path=BACKEND_DIR / "pedagogico" / "lexicon_data.py",
    max_edit_distance=2,
)

# 1. Ayrosa Página 1
# Texto antes (do banco / log anterior):
ayrosa_p1_raw = """a <
q:
=:
Sa
E
E
Ae emmerrener amem
Fes"""

# Texto do corretor antigo (do log anterior, RELATORIO_DIMENSIONAMENTO_E_VIABILIDADE.md):
ayrosa_p1_old_corr = """. inĩ - '. + 7 so 7. 7 os no se há, ‘ ne ‘ <. o pe.. MP ln + a abá oe to - ts ta Okar at. Po Mu nq ETÉ nde Oe eS Es. - ‘ > o Vo " 3. toré PE f So'o. ‘ _ ae bd 0 ” a Sa) EO esá aa oka We ( e. “ -. OE Co e O O IP SE PE AS A ARARA AWA OE SÓ + O ED PI ND PP E PR, RA, eo. Wo. o -. ’ N. -.. é. - — — - ESÁ E de A - ~..., ee. eo eo:.. abá - Ore en Ta % ES 7... e - O - - e.. - os - Lo Je., s., Moia 4 et sa - e - ' “ t.. 4 x -. ‘ an. + “ +:. o é fi: os.. - -: ‘ J. ‘... no ‘., Pe ew tg a t ~. ' | +.. mata ' “ o, o EN 7 7 + -. a -. a. - - o. o o - eo ly eo ne + -., forca a. ‘ t. a.., '... Ve. ‘.. -... - o Ba A ‘. N 7 eo. “ o. '.. “ p -.. - é s “ e. ão. EN So'o, ‘.. º. - Ce “ o. ° © -... “ -,..... «. + -. e. =. i x. ~ 4 os.:.. a:. ': o a jane. ': - og de. -: an). e: a ': - ve. - - -. 1 ne. - Rr. 1. + ' e + -. a, >. N. ‘. ore: os: - -. *.... _ - e. o. so. - -. o - +. +:.. & to 2. a. 4 - Vo. So *. -.. Í E oe te PR A -:. +. ~. - - 7 - 4 ' “ e ‘ - -. 7..... -. + ~... os - 7.. 7 7 Pá.. - 10.. -, toré - - -,, - - -., a. Cu -. no - > -. “ o...,.:. we o Vo.. +,. e « -... -. e.. '..: os A «: so - -. ‘ ha a. a - 7 o - ‘ o o “ -. N. +. - -. ‘. oka. a, - - -. _ 0 - 7:..::... ' - -. ” -. - “ ot 4 abá..: -.."""

ayrosa_p1_v3 = lexical_engine.process_text(ayrosa_p1_raw, token_confidences=[0.3473]*len(ayrosa_p1_raw.split()))

# 2. Dicionário Página 8 (uma das 10 atenção)
conn = sqlite3.connect(f"file:{BACKEND_DIR / 'vector_store.db'}?mode=ro", uri=True)
cur = conn.cursor()
cur.execute("SELECT document FROM documents WHERE metadata LIKE '%Dicion%Tupi.pdf%' AND json_extract(metadata, '$.page') = 8")
rows = cur.fetchall()
dic_p8_raw = "\n".join([r[0] for r in rows if r[0]])
dic_p8_v3 = lexical_engine.process_text(dic_p8_raw, token_confidences=[0.937]*len(dic_p8_raw.split()))

# 3. Dicionário Página 11 (caso mediano)
cur.execute("SELECT document FROM documents WHERE metadata LIKE '%Dicion%Tupi.pdf%' AND json_extract(metadata, '$.page') = 11")
rows = cur.fetchall()
conn.close()
dic_p11_raw = "\n".join([r[0] for r in rows if r[0]])
dic_p11_v3 = lexical_engine.process_text(dic_p11_raw, token_confidences=[0.4657]*len(dic_p11_raw.split()))

out_data = {
    "ayrosa_p1": {
        "raw": ayrosa_p1_raw,
        "old": ayrosa_p1_old_corr,
        "v3": ayrosa_p1_v3.corrected_text,
        "corrections_v3": [f"{c.original}->{c.corrected}" for c in ayrosa_p1_v3.corrections_applied],
        "rollbacks_v3": [f"{c.original}->{c.corrected}" for c in ayrosa_p1_v3.corrections_rolled_back],
    },
    "dic_p8": {
        "raw": dic_p8_raw,
        "v3": dic_p8_v3.corrected_text,
        "corrections_v3": [f"{c.original}->{c.corrected}" for c in dic_p8_v3.corrections_applied],
        "rollbacks_v3": [f"{c.original}->{c.corrected}" for c in dic_p8_v3.corrections_rolled_back],
    },
    "dic_p11": {
        "raw": dic_p11_raw,
        "v3": dic_p11_v3.corrected_text,
        "corrections_v3": [f"{c.original}->{c.corrected}" for c in dic_p11_v3.corrections_applied],
        "rollbacks_v3": [f"{c.original}->{c.corrected}" for c in dic_p11_v3.corrections_rolled_back],
    }
}

with open(BACKEND_DIR / "scratch" / "exact_side_by_side.json", "w", encoding="utf-8") as f:
    json.dump(out_data, f, indent=2, ensure_ascii=False)

print("Side-by-side exportado com sucesso para scratch/exact_side_by_side.json!")
print("Ayrosa p.1 correções v3:", out_data["ayrosa_p1"]["corrections_v3"])
print("Dic p.8 correções v3 count:", len(out_data["dic_p8"]["corrections_v3"]))
print("Dic p.11 correções v3 count:", len(out_data["dic_p11"]["corrections_v3"]))
