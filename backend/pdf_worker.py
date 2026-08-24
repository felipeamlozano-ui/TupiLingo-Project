r"""
TupiLingo PDF Ingestion Worker
Processa PDFs com OCR/Tesseract e indexa no banco vetorial SQLite local.
Roda como processo independente, sem Django, sem ChromaDB.

Uso: venv\Scripts\python.exe pdf_worker.py
"""
import os
import sys
import sqlite3
import hashlib
import logging
import json
import time
import io
import traceback
from pathlib import Path

# === CONFIGURACAO ===
BACKEND_DIR = Path(__file__).resolve().parent
PDFS_DIR = BACKEND_DIR / "pdfs"
DB_PATH = BACKEND_DIR / "vector_store.db"
PROGRESS_FILE = BACKEND_DIR / "ingest_progress.json"
LOG_PATH = BACKEND_DIR / "worker.log"
CHUNK_SIZE = 800
CHUNK_OVERLAP = 150
EMBEDDING_DIM = 384  # all-MiniLM-L6-v2 usa 384 dimensoes

# Caminho do Tesseract — detecta automaticamente Windows vs Linux/Docker
import platform
if platform.system() == "Windows":
    TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
else:
    TESSERACT_CMD = "tesseract"  # No Linux/Docker, está no PATH do sistema


# === LOGGING ===
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(str(LOG_PATH), encoding="utf-8", mode="w"),
    ]
)
logger = logging.getLogger("pdf_worker")

# === IMPORTS ===
try:
    import PyPDF2
    logger.info("PyPDF2 carregado.")
except ImportError:
    logger.error("PyPDF2 nao encontrado. Execute: pip install PyPDF2")
    sys.exit(1)

try:
    import numpy as np
    logger.info("NumPy carregado.")
except ImportError:
    logger.error("NumPy nao encontrado. Execute: pip install numpy")
    sys.exit(1)

TESSERACT_AVAILABLE = False
try:
    import pytesseract
    from PIL import Image
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
    pytesseract.get_tesseract_version()
    TESSERACT_AVAILABLE = True
    logger.info("Tesseract carregado.")
except Exception as e:
    logger.warning(f"Tesseract indisponivel: {e}. OCR de imagens desabilitado.")

# === BANCO DE DADOS VETORIAL (SQLite puro) ===
def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            document TEXT NOT NULL,
            embedding TEXT,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    # Não criamos índice no file_hash pois agora é parte do JSON, o SQLite lidará via json_extract
    conn.commit()
    count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    logger.info(f"Banco vetorial SQLite pronto. Documentos existentes: {count}")
    conn.close()

def has_file_hash(file_hash: str) -> bool:
    conn = sqlite3.connect(str(DB_PATH))
    count = conn.execute("SELECT COUNT(*) FROM documents WHERE json_extract(metadata, '$.file_hash')=?", (file_hash,)).fetchone()[0]
    conn.close()
    return count > 0

def save_chunks(ids, documents, embeddings, filenames, file_hashes, pages, chunk_indices):
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA journal_mode=WAL")
    for i in range(len(ids)):
        emb_json = json.dumps(embeddings[i]) if embeddings[i] else None
        meta_dict = {
            "filename": filenames[i],
            "file_hash": file_hashes[i],
            "page": pages[i],
            "chunk_index": chunk_indices[i]
        }
        meta_json = json.dumps(meta_dict, ensure_ascii=False)
        conn.execute("""
            INSERT INTO documents (id, document, embedding, metadata)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                document=excluded.document,
                embedding=excluded.embedding,
                metadata=excluded.metadata
        """, (ids[i], documents[i], emb_json, meta_json))
    conn.commit()
    conn.close()

# === LOCAL EMBEDDER ===
embedder_model = None
try:
    from sentence_transformers import SentenceTransformer
    # O modelo 'all-MiniLM-L6-v2' eh extremamente rapido e leve para rodar em CPU local
    logger.info("Carregando modelo de IA Local para Embeddings (SentenceTransformer)...")
    embedder_model = SentenceTransformer('all-MiniLM-L6-v2')
    logger.info("Modelo de IA Local carregado com sucesso (CPU).")
except Exception as e:
    logger.error(f"Erro ao carregar modelo de IA local: {e}")

def embed_texts(texts: list) -> list:
    """Gera embeddings localmente via CPU (processador offline)."""
    if not embedder_model or not texts:
        return [[0.0] * EMBEDDING_DIM for _ in texts]
    
    try:
        # Codifica localmente, converte para lista de floats
        embeddings = embedder_model.encode(texts, convert_to_numpy=True)
        return embeddings.tolist()
    except Exception as e:
        logger.warning(f"Erro gerando embeddings localmente: {e}")
        return [[0.0] * EMBEDDING_DIM for _ in texts]


# === PROCESSAMENTO DE PDF ===
def chunk_text(text: str) -> list:
    chunks = []
    text = text.strip()
    start = 0
    while start < len(text):
        end = min(start + CHUNK_SIZE, len(text))
        chunk = text[start:end].strip()
        if len(chunk) > 30:  # ignora chunks muito pequenos
            chunks.append(chunk)
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks


def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        try:
            return json.loads(PROGRESS_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_progress(progress: dict):
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2), encoding="utf-8")


def get_file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(8192), b""):
            h.update(block)
    return h.hexdigest()


def process_pdf(pdf_path: Path, file_hash: str, progress: dict):
    filename = pdf_path.name
    prog_key = file_hash
    last_page = progress.get(prog_key, {}).get("last_page", 0)
    chunk_counter = progress.get(prog_key, {}).get("chunk_counter", 0)

    logger.info(f"\n{'='*60}")
    logger.info(f"Processando: {filename} ({pdf_path.stat().st_size / 1024 / 1024:.1f} MB)")
    if last_page > 0:
        logger.info(f"Retomando da pagina {last_page + 1}...")

    try:
        with open(pdf_path, "rb") as f:
            reader = PyPDF2.PdfReader(f)
            total_pages = len(reader.pages)
        logger.info(f"Total de paginas: {total_pages}")
    except Exception as e:
        logger.error(f"Nao foi possivel abrir {filename}: {e}")
        return

    # Processa pagina por pagina (nunca carrega tudo na RAM)
    pending_ids = []
    pending_docs = []
    pending_filenames = []
    pending_hashes = []
    pending_pages = []
    pending_indices = []

    try:
        with open(pdf_path, "rb") as f:
            reader = PyPDF2.PdfReader(f)
            for page_num in range(last_page, total_pages):
                page = reader.pages[page_num]
                page_text = ""

                # Extrai texto diretamente
                try:
                    page_text = page.extract_text() or ""
                except Exception as e:
                    logger.warning(f"  Erro extraindo texto pagina {page_num+1}: {e}")

                # Fallback OCR se texto insuficiente
                if len(page_text.strip()) < 20 and TESSERACT_AVAILABLE:
                    try:
                        for img_obj in page.images:
                            try:
                                img = Image.open(io.BytesIO(img_obj.data))
                                ocr_text = pytesseract.image_to_string(img, lang="por")
                                page_text += ocr_text + "\n"
                                img.close()
                            except Exception as e:
                                logger.warning(f"  OCR imagem pag {page_num+1}: {e}")
                    except Exception as e:
                        logger.warning(f"  Erro imagens pag {page_num+1}: {e}")

                # Divide em chunks
                for chunk in chunk_text(page_text):
                    pending_ids.append(f"{file_hash}_chunk_{chunk_counter}")
                    pending_docs.append(chunk)
                    pending_filenames.append(filename)
                    pending_hashes.append(file_hash)
                    pending_pages.append(page_num + 1)
                    pending_indices.append(chunk_counter)
                    chunk_counter += 1

                # Persiste a cada 30 chunks (sem acumular muita RAM)
                if len(pending_ids) >= 30:
                    logger.info(f"  Gerando embeddings para {len(pending_ids)} chunks...")
                    embeddings = embed_texts(pending_docs)
                    save_chunks(pending_ids, pending_docs, embeddings,
                                pending_filenames, pending_hashes, pending_pages, pending_indices)
                    logger.info(f"  OK: {len(pending_ids)} chunks salvos.")
                    pending_ids, pending_docs, pending_filenames = [], [], []
                    pending_hashes, pending_pages, pending_indices = [], [], []

                # Salva progresso a cada 25 paginas
                if (page_num + 1) % 25 == 0:
                    progress[prog_key] = {"last_page": page_num + 1, "chunk_counter": chunk_counter}
                    save_progress(progress)
                    logger.info(f"  Progresso salvo: pagina {page_num+1}/{total_pages}")

        # Salva o restante
        if pending_ids:
            logger.info(f"  Gerando embeddings para os ultimos {len(pending_ids)} chunks...")
            embeddings = embed_texts(pending_docs)
            save_chunks(pending_ids, pending_docs, embeddings,
                        pending_filenames, pending_hashes, pending_pages, pending_indices)

        progress[prog_key] = {"last_page": total_pages, "chunk_counter": chunk_counter, "done": True}
        save_progress(progress)
        logger.info(f"CONCLUIDO: {filename} | {chunk_counter} chunks indexados.")

    except Exception as e:
        logger.error(f"Erro fatal em {filename}: {e}")
        traceback.print_exc()


def main():
    logger.info("=" * 60)
    logger.info("  TupiLingo PDF Ingestion Worker (SQLite + NumPy)")
    logger.info(f"  Banco: {DB_PATH}")
    logger.info(f"  Logs:  {LOG_PATH}")
    logger.info("=" * 60)

    init_db()

    if not PDFS_DIR.exists():
        logger.error(f"Diretorio de PDFs nao encontrado: {PDFS_DIR}")
        return

    pdfs = sorted(PDFS_DIR.glob("*.pdf"), key=lambda p: p.stat().st_size)
    if not pdfs:
        logger.info("Nenhum PDF encontrado.")
        return

    logger.info(f"Encontrados {len(pdfs)} PDFs.")
    progress = load_progress()

    for pdf_path in pdfs:
        try:
            file_hash = get_file_hash(pdf_path)
            if progress.get(file_hash, {}).get("done"):
                logger.info(f"PULANDO: {pdf_path.name} (ja processado)")
                continue
            # Dupla verificacao no banco
            if has_file_hash(file_hash):
                logger.info(f"PULANDO: {pdf_path.name} (ja esta no banco)")
                progress[file_hash] = {"done": True}
                save_progress(progress)
                continue
            process_pdf(pdf_path, file_hash, progress)
        except Exception as e:
            logger.error(f"Erro com {pdf_path.name}: {e}")
            traceback.print_exc()

    logger.info("\n" + "=" * 60)
    logger.info("  Ingestao concluida!")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
