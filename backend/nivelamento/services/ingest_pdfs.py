import os
import hashlib
import logging
from pathlib import Path

from django.conf import settings
import PyPDF2

from nivelamento.services.rag_service import db

logger = logging.getLogger("nivelamento.ingest")

def chunk_text(text: str, chunk_size: int = 1000, overlap: int = 200) -> list[str]:
    """Divide o texto em pequenos pedaços com um pouco de sobreposição."""
    chunks = []
    start = 0
    text_len = len(text)
    
    while start < text_len:
        end = min(start + chunk_size, text_len)
        chunks.append(text[start:end])
        start += chunk_size - overlap
        
    return chunks

def ingest_new_pdfs() -> None:
    """Verifica a pasta de PDFs e ingere arquivos novos no banco nativo."""
    pdfs_dir = settings.BASE_DIR / "pdfs"
    if not pdfs_dir.exists():
        pdfs_dir.mkdir(parents=True, exist_ok=True)
        return

    for pdf_path in pdfs_dir.glob("*.pdf"):
        filename = pdf_path.name
        
        # Gera hash do arquivo
        hasher = hashlib.md5()
        with open(pdf_path, 'rb') as f:
            buf = f.read()
            hasher.update(buf)
        file_hash = hasher.hexdigest()
        
        # Verifica se já processou
        if db.get_existing_file_hash(file_hash):
            continue
            
        logger.info(f"[INGEST] Processando novo PDF: {filename}")
        
        # Extrai texto do PDF
        full_text = ""
        try:
            with open(pdf_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                for i, page in enumerate(reader.pages):
                    if i % 10 == 0:
                        logger.info(f"[INGEST] Lendo página {i+1}/{len(reader.pages)} do arquivo {filename}...")
                    text = page.extract_text()
                    if text:
                        full_text += text + "\n"
        except Exception as e:
            logger.error(f"[INGEST] Erro ao ler PDF {filename}: {e}")
            continue
            
        if not full_text.strip():
            logger.warning(f"[INGEST] PDF {filename} não contém texto extraível.")
            continue
            
        chunks = chunk_text(full_text)
        
        ids = []
        documents = []
        metadatas = []
        
        for i, chunk in enumerate(chunks):
            chunk_id = f"{file_hash}_chunk_{i}"
            ids.append(chunk_id)
            documents.append(chunk)
            metadatas.append({
                "filename": filename,
                "file_hash": file_hash,
                "chunk_index": i
            })
            
        # Insere tudo direto no banco SQLite sem chamar APIs (Super rápido!)
        if ids:
            try:
                db.upsert(ids, documents, metadatas)
                logger.info(f"[INGEST] {len(ids)} pedaços de '{filename}' salvos com sucesso no BM25 local!")
            except Exception as e:
                logger.error(f"[INGEST] Erro ao salvar pedaços do PDF no banco: {e}")
