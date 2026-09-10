import os
import hashlib
from pathlib import Path

pdfs_dir = Path("/app/pdfs")
print("PDF hashes:")
for p in sorted(pdfs_dir.glob("*.pdf")):
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    print(f"{h} : {p.name}")
