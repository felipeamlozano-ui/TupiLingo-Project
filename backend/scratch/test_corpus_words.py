import sqlite3
import time
import re

t0 = time.time()
conn = sqlite3.connect("file:vector_store.db?mode=ro", uri=True)
cur = conn.cursor()
cur.execute("SELECT document FROM documents")
words = set()
for r in cur.fetchall():
    if r[0]:
        for w in re.findall(r"[\w'-]+", r[0].lower()):
            words.add(w)

print(f"Extracted {len(words)} unique words from 22k documents in {time.time()-t0:.2f}s!")
