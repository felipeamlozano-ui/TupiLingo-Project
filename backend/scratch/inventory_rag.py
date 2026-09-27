import sqlite3
import json
from collections import defaultdict

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Map PDF files to variants
file_variant_map = {
    'tupi_antigo': [
        'Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf',
        'Fernandes_1924_GrammaticaTupy.pdf',
        'Dicionrio Tupi.pdf',
        'Masucci_1979_DicionarioTupiPortugues.pdf',
        'Cascudo_1988_DicionarioDoFolcloreBrasileiro_OCR.pdf',
        'Mistieri_2010_Acento_Tupi_Antigo.pdf'
    ],
    'tupinamba': [
        'Rodrigues_1958_Phonologie_der_Tupinamba.pdf',
        'Rodrigues_2011_AnaliseMorfologicaDeUmTextoTupi.pdf',
        'Transcrio e Traduo Carta 1645.pdf',
        'Tupinamb.+com.pdf',
        'download.pdf'
    ],
    'kamaiura': [
        'sek00kamaiura.pdf',
        'seki_1976_kamaiura.pdf',
        'LenitionandnasalizationinKamaiura-anOTperspective.pdf'
    ],
    'tupi_contemporaneo': [
        'tupi-potiguara-kuapa-2023_compress.pdf',
        'CURSO DE LNGUA GERAL (NHEENGATU).pdf',
        'Dietrich_2025_GramaticaDaLinguaGeralDoBrazil.pdf',
        'Freire&Rosa_2003_LinguasGerais_PoliticaLingECatequese.pdf',
        'inclusartiz_apostila-de-tupi-guarani.pdf'
    ]
}

print("=== INVENTORY OF RAG DOCUMENTS PER VARIANT ===")
for var, files in file_variant_map.items():
    total_chunks = 0
    print(f"\nVariant: {var}")
    for fn in files:
        prefix = fn[:15]
        cursor.execute("SELECT COUNT(*) FROM documents WHERE json_extract(metadata, '$.filename') LIKE ?", (f"%{prefix}%",))
        count = cursor.fetchone()[0]
        total_chunks += count
        print(f"  - {fn}: {count} chunks")
    print(f"  TOTAL for {var}: {total_chunks} chunks")

conn.close()
