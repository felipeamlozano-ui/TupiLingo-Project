r"""
TupiLingo PDF Ingestion Worker
Processa PDFs com OCR/Tesseract e indexa no banco vetorial SQLite local.
Roda como processo independente, sem Django, sem ChromaDB.

Uso: venv\Scripts\python.exe pdf_worker.py
"""
import hashlib
import io
import json
import logging
import sqlite3
import sys
import time
import traceback
from pathlib import Path

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


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(str(LOG_PATH), encoding="utf-8", mode="w"),
    ]
)
logger = logging.getLogger("pdf_worker")

try:
    import PyPDF2
    logger.info("PyPDF2 carregado.")
except ImportError:
    logger.error("PyPDF2 nao encontrado. Execute: pip install PyPDF2")

try:
    import numpy as np
    logger.info("NumPy carregado.")
except ImportError:
    logger.error("NumPy nao encontrado. Execute: pip install numpy")

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

def _ocr_image_with_auto_orientation(img: Image.Image) -> str:
    """
    Executa OCR aplicando correcao automatica de orientacao caso a pagina
    esteja digitalizada de cabeca para baixo (180 graus) ou invertida.
    Valida a legibilidade do texto em lingua portuguesa/tupi.
    """
    if not TESSERACT_AVAILABLE:
        return ""
    
    # 1. Tenta deteccao automatica rapida via OSD
    try:
        osd = pytesseract.image_to_osd(img)
        rotate_angle = 0
        for line in osd.splitlines():
            if line.startswith("Rotate:"):
                rotate_angle = int(line.split(":")[1].strip())
                break
        if rotate_angle in (90, 180, 270):
            return pytesseract.image_to_string(img.rotate(rotate_angle, expand=True), lang="por+eng")
    except Exception:
        pass

    # 2. Heuristica de legibilidade (Normal vs 180 graus) — suporta Portugues, Tupi e Ingles
    txt_normal = pytesseract.image_to_string(img, lang="por+eng")
    common_words = (
        # Português / Tupi
        " de ", " para ", " em ", " com ", " não ", " tupi ", " que ", " por ", " da ", " do ",
        # Inglês (artigos acadêmicos / fontes internacionais)
        " the ", " and ", " of ", " to ", " in ", " with ", " is ", " that ", " for ", " as ", " on "
    )
    normal_score = sum(1 for w in common_words if w in txt_normal.lower())

    # Se a pontuacao normal for muito baixa e houver texto, testa 180 graus
    if normal_score <= 1 and len(txt_normal.strip()) > 30:
        txt_180 = pytesseract.image_to_string(img.rotate(180, expand=True), lang="por+eng")
        score_180 = sum(1 for w in common_words if w in txt_180.lower())
        if score_180 > normal_score:
            return txt_180

    return txt_normal

def _get_db_connection(timeout: float = 30.0) -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH), timeout=timeout)
    conn.execute("PRAGMA busy_timeout = 30000")
    conn.execute("PRAGMA journal_mode = TRUNCATE")
    conn.execute("PRAGMA synchronous = NORMAL")
    return conn

def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = _get_db_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            document TEXT NOT NULL,
            embedding TEXT,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    logger.info(f"Banco vetorial SQLite pronto. Documentos existentes: {count}")
    conn.close()

def has_file_hash(file_hash: str) -> bool:
    conn = _get_db_connection()
    count = conn.execute("SELECT COUNT(*) FROM documents WHERE json_extract(metadata, '$.file_hash')=?", (file_hash,)).fetchone()[0]
    conn.close()
    return count > 0

def save_chunks(ids, documents, embeddings, filenames, file_hashes, pages, chunk_indices):
    max_retries = 5
    for attempt in range(max_retries):
        try:
            conn = _get_db_connection()
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
            return
        except sqlite3.OperationalError as e:
            logger.warning(f"Erro SQLite (tentativa {attempt+1}/{max_retries}): {e}. Tentando novamente em 1s...")
            time.sleep(1.0)
            if attempt == max_retries - 1:
                raise

_embedder_model = None

def get_worker_embedder():
    global _embedder_model
    if _embedder_model is None:
        try:
            from fastembed import TextEmbedding
            logger.info("Carregando modelo FastEmbed para Embeddings no Worker...")
            _embedder_model = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")
        except Exception as e:
            logger.error(f"Erro ao carregar modelo FastEmbed: {e}")
    return _embedder_model

def embed_texts(texts: list) -> list:
    """Gera embeddings localmente via CPU (processador offline) usando FastEmbed ONNX."""
    model = get_worker_embedder()
    if not model or not texts:
        return [[0.0] * EMBEDDING_DIM for _ in texts]
    
    try:
        # FastEmbed retorna gerador de numpy arrays de 384 dimensões
        embeddings = list(model.embed(texts))
        return [emb.tolist() for emb in embeddings]
    except Exception as e:
        logger.warning(f"Erro gerando embeddings localmente: {e}")
        return [[0.0] * EMBEDDING_DIM for _ in texts]


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


def process_pdf(pdf_path: Path, file_hash: str, progress: dict) -> int:
    filename = pdf_path.name
    prog_key = file_hash
    last_page = progress.get(prog_key, {}).get("last_page", 0)
    chunk_counter = progress.get(prog_key, {}).get("chunk_counter", 0)
    initial_chunk_counter = chunk_counter

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
        return 0

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
                                ocr_text = _ocr_image_with_auto_orientation(img)
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

        return chunk_counter - initial_chunk_counter

    except Exception as e:
        logger.error(f"Erro fatal em {filename}: {e}")
        traceback.print_exc()
        return 0


def main():
    logger.info("=" * 60)
    logger.info("  TupiLingo PDF Ingestion Worker (Contínuo)")
    logger.info(f"  Banco: {DB_PATH}")
    logger.info(f"  Logs:  {LOG_PATH}")
    logger.info("=" * 60)

    init_db()

    if not PDFS_DIR.exists():
        logger.error(f"Diretorio de PDFs nao encontrado: {PDFS_DIR}")
        return

    while True:
        try:
            pdfs = sorted(PDFS_DIR.glob("*.pdf"), key=lambda p: p.stat().st_size)
            if not pdfs:
                time.sleep(30)
                continue

            progress = load_progress()
            processed_any = False
            total_new_chunks = 0

            for pdf_path in pdfs:
                try:
                    file_hash = get_file_hash(pdf_path)
                    if progress.get(file_hash, {}).get("done"):
                        continue
                    if has_file_hash(file_hash):
                        progress[file_hash] = {"done": True}
                        save_progress(progress)
                        continue
                    
                    new_chunks = process_pdf(pdf_path, file_hash, progress)
                    if new_chunks > 0:
                        total_new_chunks += new_chunks
                        processed_any = True
                except Exception as e:
                    logger.error(f"Erro com {pdf_path.name}: {e}")
                    traceback.print_exc()

            if processed_any:
                logger.info("\n" + "=" * 60)
                logger.info("  Ingestao de novos PDFs concluida!")
                logger.info(f"  {total_new_chunks} novos chunks extraídos.")
                logger.info("=" * 60)
                
                if total_new_chunks > 0:
                    logger.info("  Aguardando o vocab_worker processar os novos vetores em background...")
            
            # Aguarda 30 minutos (1800s) antes de verificar novamente
            time.sleep(1800)
            
        except KeyboardInterrupt:
            logger.info("Worker interrompido pelo usuário.")
            break
        except Exception as e:
            logger.error(f"Erro no loop do worker: {e}")
            time.sleep(1800)


if __name__ == "__main__":
    main()
