import sqlite3
import json
import re

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Categories to audit
categories = [
    'saudacoes_cumprimentos',
    'pessoas_parentesco',
    'fauna_animais',
    'flora_plantas_alimentos',
    'natureza_elementos',
    'aldeia_casa_utensilios',
    'corpo_humano',
    'acoes_verbos_cotidiano',
    'mitologia_cosmologia',
    'historia_contato',
    'toponimia_geografia',
    'gramatica_morfologia'
]

# We will search for evidence in the chunks
print("Starting deep vocabulary and grammar audit across variants...")
# Let's inspect Seki for Kamaiura
cursor.execute("""
    SELECT id, document, metadata FROM documents 
    WHERE json_extract(metadata, '$.filename') = 'sek00kamaiura.pdf'
    AND (document LIKE '%vocabul%' OR document LIKE '%glossrio%' OR document LIKE '%substantivo%' OR document LIKE '%verbo%')
    LIMIT 10
""")
seki_samples = cursor.fetchall()
print(f"Kamaiura sample chunks with linguistic keywords: {len(seki_samples)}")

conn.close()
