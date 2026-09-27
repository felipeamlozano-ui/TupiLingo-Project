import sqlite3
import json

conn = sqlite3.connect('vector_store.db')
cursor = conn.cursor()
cursor.execute('SELECT id, document, metadata, precisa_revisao, confianca, metodo_classificacao FROM documents ORDER BY created_at DESC LIMIT 4')
for row in cursor.fetchall():
    print('='*60)
    print(f"ID: {row[0]}")
    print(f"precisa_revisao: {row[3]} | confianca: {row[4]} | metodo: {row[5]}")
    meta = json.loads(row[2])
    print(f"Filename: {meta.get('filename')} | Pág: {meta.get('page')}")
    print(f"OCR Conf Mean: {meta.get('ocr_conf_mean')}% | Min: {meta.get('ocr_conf_min')}% | Metodo Extração: {meta.get('metodo_extracao')}")
    print(f"Snippet: {repr(row[1][:120])}")
