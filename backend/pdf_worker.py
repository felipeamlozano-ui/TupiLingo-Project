r"""
TupiLingo PDF Ingestion Worker (Pipeline de OCR e Ingestão Resiliente)
Processa PDFs com OCR/Tesseract, pré-processamento OpenCV a 300 DPI,
chunking linguístico consciente, deduplicação em tempo de ingestão,
captura de confiança de OCR e integração com fila de revisão.

Uso:
  .\venv\Scripts\python.exe pdf_worker.py [--pdf nome.pdf] [--limit-pages N] [--reprocess-all]
"""
import os
import sys
import sqlite3
import hashlib
import logging
import json
import time
import io
import re
import argparse
import traceback
from pathlib import Path
from typing import Optional, Tuple, List, Dict, Any

BACKEND_DIR = Path(__file__).resolve().parent
PDFS_DIR = BACKEND_DIR / "pdfs"
DB_PATH = BACKEND_DIR / "vector_store.db"
PROGRESS_FILE = BACKEND_DIR / "ingest_progress.json"
LOG_PATH = BACKEND_DIR / "worker.log"
TUPI_WORDS_FILE = BACKEND_DIR / "tupi_user_words.txt"

# Parâmetros de Ingestão e Qualidade
TARGET_DPI = 300
MIN_PAGE_CHARS_DIGITAL = 120     # Mínimo de texto digital para dispensar OCR
OCR_LOW_CONF_THRESHOLD = 60.0     # Confiança média do OCR abaixo deste valor marca precisa_revisao=1
CHUNK_TARGET_MIN = 500           # Tamanho mínimo alvo do chunk em caracteres
CHUNK_TARGET_MAX = 850           # Tamanho máximo alvo do chunk em caracteres
EMBEDDING_DIM = 384              # Dimensão de embeddings para all-MiniLM-L6-v2

# Detecção automática do binário Tesseract (Windows vs Linux/Docker)
import platform
if platform.system() == "Windows":
    TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
else:
    TESSERACT_CMD = "tesseract"

try:
    sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(str(LOG_PATH), encoding="utf-8", mode="a"),
    ]
)
logger = logging.getLogger("pdf_worker")


# ── LAZY LOADERS PARA DEPENDÊNCIAS PESADAS ───────────────────────────────────

_pypdf2_module = None
def _get_pypdf2():
    global _pypdf2_module
    if _pypdf2_module is None:
        try:
            import PyPDF2
            _pypdf2_module = PyPDF2
        except ImportError:
            logger.error("PyPDF2 não encontrado. Execute: pip install PyPDF2")
    return _pypdf2_module

_pypdfium2_module = None
def _get_pypdfium2():
    global _pypdfium2_module
    if _pypdfium2_module is None:
        try:
            import pypdfium2 as pdfium
            _pypdfium2_module = pdfium
        except ImportError:
            logger.warning("pypdfium2 não encontrado. Rasterização em 300 DPI usará fallback.")
    return _pypdfium2_module

_cv2_module = None
_np_module = None
def _get_cv2_and_numpy():
    global _cv2_module, _np_module
    if _cv2_module is None:
        try:
            import cv2
            import numpy as np
            _cv2_module = cv2
            _np_module = np
        except ImportError:
            logger.warning("OpenCV/numpy não disponíveis para pré-processamento avançado.")
    return _cv2_module, _np_module

_tesseract_status = None
_pytesseract_module = None
_pil_image_module = None
def _get_tesseract_and_pil():
    global _tesseract_status, _pytesseract_module, _pil_image_module
    if _tesseract_status is None:
        try:
            import pytesseract
            from PIL import Image
            pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
            pytesseract.get_tesseract_version()
            _pytesseract_module = pytesseract
            _pil_image_module = Image
            _tesseract_status = True
            logger.info("Tesseract OCR inicializado com sucesso.")
        except Exception as e:
            logger.warning(f"Tesseract indisponível ({e}). OCR desabilitado.")
            _tesseract_status = False
    return _tesseract_status, _pytesseract_module, _pil_image_module


# ── PRÉ-PROCESSAMENTO DE IMAGEM (OPENCV: ORIENTAÇÃO, DESKEW, DENOISE, OTSU) ──

def check_and_fix_orientation(pil_img) -> Tuple[Any, int]:
    """Detecta se a página está rotacionada (90°, 180°, 270°) e corrige usando OSD do Tesseract."""
    tess_avail, pytesseract, _ = _get_tesseract_and_pil()
    if not tess_avail or pytesseract is None:
        return pil_img, 0
    try:
        w, h = pil_img.size
        thumb_w = min(w, 600)
        thumb_h = max(1, int(h * (thumb_w / w)))
        thumb = pil_img.resize((thumb_w, thumb_h))
        osd = pytesseract.image_to_osd(thumb)
        rot_match = re.search(r"Rotate:\s*(\d+)", osd)
        if rot_match:
            rot_deg = int(rot_match.group(1))
            if rot_deg in (90, 180, 270):
                logger.info(f"    Orientação corrigida: rotacionando {360 - rot_deg}° (detectado Rotate={rot_deg}°)")
                return pil_img.rotate(360 - rot_deg, expand=True), rot_deg
    except Exception:
        pass
    return pil_img, 0

def preprocess_image_for_ocr(pil_img) -> Tuple[Any, float, Dict[str, Any]]:
    """
    Aplica pipeline robusto de pré-processamento de imagem via OpenCV:
      0. Deteccão e correção de orientação 90°/180°/270° via OSD.
      1. Conversão para escala de cinza.
      2. Upscaling suave se a imagem for menor que 1200px de largura.
      3. Deteccão e correção de inclinação (deskew) via minAreaRect.
      4. Redução de ruído (denoise gaussiano suave).
      5. Binarização adaptativa Otsu.
    Retorna: (imagem_pil_processada, angulo_inclinacao, metricas)
    """
    cv2, np = _get_cv2_and_numpy()
    _, _, Image_lib = _get_tesseract_and_pil()
    if cv2 is None or np is None or Image_lib is None:
        return pil_img, 0.0, {"preprocessed": False}

    try:
        pil_img, rot_deg = check_and_fix_orientation(pil_img)
        # Converte PIL para array BGR OpenCV
        cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        h, w = cv_img.shape[:2]

        # 1. Upscaling se a resolução for muito baixa (<1200px de largura)
        scale_factor = 1.0
        if w < 1200:
            scale_factor = 1200.0 / w
            cv_img = cv2.resize(cv_img, (0, 0), fx=scale_factor, fy=scale_factor, interpolation=cv2.INTER_CUBIC)
            h, w = cv_img.shape[:2]

        # 2. Escala de cinza
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)

        # 3. Denoise suave
        blurred = cv2.GaussianBlur(gray, (3, 3), 0)

        # 4. Binarização Otsu
        _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        # 5. Deskew fino (correção de ângulo)
        coords = np.column_stack(np.where(binary == 0))
        angle = 0.0
        if len(coords) > 50:
            rect = cv2.minAreaRect(coords)
            angle = rect[-1]
            if angle < -45:
                angle = -(90 + angle)
            else:
                angle = -angle

            # Apenas corrige se o desvio for perceptível e razoável (>0.4 e <15 graus)
            if 0.4 < abs(angle) < 15.0:
                center = (w // 2, h // 2)
                M = cv2.getRotationMatrix2D(center, angle, 1.0)
                binary = cv2.warpAffine(
                    binary, M, (w, h),
                    flags=cv2.INTER_CUBIC,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=255
                )

        processed_pil = Image_lib.fromarray(binary)
        metrics = {
            "preprocessed": True,
            "scale_factor": scale_factor,
            "skew_angle": angle,
            "final_width": w,
            "final_height": h,
        }
        return processed_pil, angle, metrics

    except Exception as exc:
        logger.warning(f"Falha no pré-processamento OpenCV ({exc}). Usando imagem original.")
        return pil_img, 0.0, {"preprocessed": False, "error": str(exc)}


# ── EXTRAÇÃO OCR COM CAPTURA DE CONFIANÇA E DICIONÁRIO TUPI ──────────────────

def ocr_image_with_confidence(
    pil_img,
    psm_mode: int = 3,
) -> Tuple[str, float, float, List[Dict[str, Any]]]:
    """
    Executa OCR via Tesseract capturando métricas de confiança por palavra e bounding boxes.
    Utiliza:
      - --oem 1 (motor neural LSTM)
      - --psm configurável (3=automático, 6=bloco de texto uniforme)
      - --user-words tupi_user_words.txt (dicionário de vocabulário Tupi autenticado)
    Retorna: (texto_completo, confianca_media, confianca_minima, lista_palavras_boxes)
    """
    tess_avail, pytesseract, _ = _get_tesseract_and_pil()
    if not tess_avail or pytesseract is None:
        return "", 0.0, 0.0, []

    # Configuração de argumentos para o Tesseract
    config_parts = [f"--oem 1 --psm {psm_mode}"]
    if TUPI_WORDS_FILE.exists():
        # Passa dicionário de palavras Tupi conhecidas
        config_parts.append(f'--user-words "{TUPI_WORDS_FILE}"')
    
    tess_config = " ".join(config_parts)

    try:
        data = pytesseract.image_to_data(
            pil_img,
            lang="por+eng",
            config=tess_config,
            output_type=pytesseract.Output.DICT,
        )

        words_data = []
        confidences = []
        reconstructed_lines = {}

        n_boxes = len(data["text"])
        for i in range(n_boxes):
            text = data["text"][i].strip()
            conf = float(data["conf"][i])
            if not text or conf < 0:
                continue

            confidences.append(conf)
            line_idx = (data["page_num"][i], data["block_num"][i], data["par_num"][i], data["line_num"][i])
            if line_idx not in reconstructed_lines:
                reconstructed_lines[line_idx] = []
            reconstructed_lines[line_idx].append(text)

            words_data.append({
                "text": text,
                "conf": conf,
                "left": data["left"][i],
                "top": data["top"][i],
                "width": data["width"][i],
                "height": data["height"][i],
            })

        # Reconstrução do texto respeitando quebras de linha detectadas
        full_lines = [" ".join(words) for words in reconstructed_lines.values()]
        full_text = "\n".join(full_lines).strip()

        if confidences:
            conf_mean = sum(confidences) / len(confidences)
            conf_min = min(confidences)
        else:
            conf_mean = 0.0
            conf_min = 0.0

        return full_text, conf_mean, conf_min, words_data

    except Exception as exc:
        logger.warning(f"Erro no Tesseract OCR com dados de confiança: {exc}")
        return "", 0.0, 0.0, []


# ── VALIDAÇÃO DE SANIDADE PÓS-OCR (DETERMINÍSTICA) ────────────────────────────

def validar_sanidade_chunk(text: str) -> Tuple[bool, str]:
    """
    Valida a higidez do texto extraído segundo critérios objetivos determinísticos:
      1. Rejeita linhas pontilhadas de sumário/índice ('.........').
      2. Rejeita proporção excessiva de caracteres não-alfabéticos / ruído de OCR (>18%).
      3. Rejeita sequências repetitivas anômalas (ex.: '_____', '.....', 'aaaaa').
      4. Rejeita comprimento insuficiente (<40 caracteres).
      5. Rejeita blocos com proporção anormal de palavras sem nenhuma vogal válida (>35%).
    Retorna: (is_healthy, motivo)
    """
    clean = text.strip()
    total_len = len(clean)
    if total_len < 40:
        return False, "comprimento_insuficiente"

    # 1. Linhas de sumário com pontilhados repetidos
    dotted_matches = re.findall(r"\.{4,}|(?:\.\s*){5,}", clean)
    if len(dotted_matches) >= 2 or sum(len(m) for m in dotted_matches) > 30:
        return False, "sumario_pontilhado"

    # 2. Caracteres estranhos ou símbolos fora do alfabeto latino/diacríticos normais
    strange_chars = len(re.findall(r"[^\w\s\.,;:!?\-\'\"()\[\]/«»–—\u00C0-\u017F\u1E00-\u1EFF]", clean))
    if (strange_chars / total_len) > 0.18:
        return False, "excesso_caracteres_nao_alfabeticos"

    # 3. Sequências repetidas anômalas
    if re.search(r"(\S)\1{5,}", clean):
        return False, "sequencia_repetitiva_anomala"

    # 4. Proporção de palavras sem vogal (ruído típico de scan com falha: 'frt klp xz')
    words = [w for w in re.split(r"\s+", clean) if len(w) >= 3]
    if len(words) >= 5:
        words_without_vowels = sum(1 for w in words if not re.search(r"[aeiouyãẽĩõũỹáéíóúâêîôûàèìòùäëïöü]", w, re.IGNORECASE))
        if (words_without_vowels / len(words)) > 0.35:
            return False, "ruido_ocr_sem_vogais"

    return True, "valido"


# ── DETECÇÃO DE NEAR-DUPLICATES E SIMILARIDADE LINGUÍSTICA ───────────────────

def compute_shingles(text: str) -> set:
    """Extrai conjunto de 3-gramas de palavras para detecção de near-duplicates."""
    words = re.findall(r"\w+", text.lower())
    if len(words) < 3:
        return set(words)
    return set(" ".join(words[i:i+3]) for i in range(len(words)-2))

def is_near_duplicate(shingles: set, seen_shingles: List[set], threshold: float = 0.82) -> bool:
    """Verifica se o chunk possui similaridade Jaccard >= threshold com chunks anteriores."""
    if not shingles:
        return False
    for s_prev in seen_shingles:
        inter = len(shingles & s_prev)
        union = len(shingles | s_prev)
        if union > 0 and (inter / union) >= threshold:
            return True
    return False


# ── CHUNKING CONSCIENTE DE ESTRUTURA LINGUÍSTICA ──────────────────────────────

def chunk_text_linguistic(
    text: str,
    page_num: int,
    file_hash: str,
    filename: str,
    ocr_conf_mean: float = 100.0,
    ocr_conf_min: float = 100.0,
    metodo_extracao: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Divide o texto preservando fronteiras naturais de parágrafos e sentenças.
    Evita quebra no meio de palavras ou orações gramaticais.
    Gera metadados ricos de rastreabilidade (rag_id, confianças de OCR, content_hash).
    """
    clean_text = text.strip()
    if not clean_text:
        return []

    # Quebra inicial por parágrafos duplos ou quebras de seção
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n+", clean_text) if p.strip()]
    
    # Divide parágrafos grandes em sentenças
    units: List[str] = []
    for para in paragraphs:
        if len(para) <= CHUNK_TARGET_MAX:
            units.append(para)
        else:
            # Divide por quebra de sentença (. ! ?)
            sentences = re.split(r"(?<=[.!?])\s+", para)
            for s in sentences:
                s_clean = s.strip()
                if s_clean:
                    units.append(s_clean)

    # Agrupa unidades respeitando faixa de tamanho alvo
    chunks = []
    current_chunk: List[str] = []
    current_length = 0

    for unit in units:
        unit_len = len(unit)
        if current_length + unit_len + 1 <= CHUNK_TARGET_MAX:
            current_chunk.append(unit)
            current_length += unit_len + 1
        else:
            if current_chunk:
                chunks.append(" ".join(current_chunk))
                # Overlap semântico: preserva a última sentença se for razoável
                last_unit = current_chunk[-1]
                if len(last_unit) < 200:
                    current_chunk = [last_unit, unit]
                    current_length = len(last_unit) + unit_len + 1
                else:
                    current_chunk = [unit]
                    current_length = unit_len
            else:
                chunks.append(unit)
                current_chunk = []
                current_length = 0

    if current_chunk:
        chunks.append(" ".join(current_chunk))

    # Formata objetos de saída com validação de sanidade e metadados
    chunk_objects = []
    for idx, raw_chunk in enumerate(chunks):
        if len(raw_chunk) < 35:
            continue

        is_healthy, reason = validar_sanidade_chunk(raw_chunk)
        
        # Marcação de proveniência e necessidade de revisão
        precisa_revisao = 0
        if not is_healthy:
            precisa_revisao = 1
        elif ocr_conf_mean < OCR_LOW_CONF_THRESHOLD:
            precisa_revisao = 1

        norm_content = re.sub(r"\s+", " ", raw_chunk.strip().lower())
        content_hash = hashlib.sha256(norm_content.encode("utf-8")).hexdigest()
        chunk_id = f"{file_hash[:12]}_p{page_num}_c{idx}"

        met_ext = metodo_extracao if metodo_extracao else ("ocr" if ocr_conf_mean < 99.0 else "digital_text")

        chunk_objects.append({
            "chunk_id": chunk_id,
            "document": raw_chunk,
            "page": page_num,
            "chunk_index": idx,
            "filename": filename,
            "file_hash": file_hash,
            "content_hash": content_hash,
            "ocr_conf_mean": round(ocr_conf_mean, 2),
            "ocr_conf_min": round(ocr_conf_min, 2),
            "is_healthy": is_healthy,
            "sanity_reason": reason,
            "precisa_revisao": precisa_revisao,
            "metodo_extracao": met_ext,
        })

    return chunk_objects


# ── BANCO DE DADOS E PERSISTÊNCIA ─────────────────────────────────────────────

def _get_db_connection(timeout: float = 30.0) -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH), timeout=timeout)
    conn.execute("PRAGMA busy_timeout = 30000")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    return conn

def init_db():
    """Inicializa banco SQLite garantindo as colunas de proveniência e revisão."""
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
    cursor = conn.cursor()
    existing_cols = [row[1] for row in cursor.execute("PRAGMA table_info(documents)").fetchall()]
    novas_colunas = [
        ("category_extracted", "INTEGER DEFAULT 0"),
        ("categoria", "TEXT"),
        ("metodo_classificacao", "TEXT DEFAULT 'llm'"),
        ("confianca", "REAL DEFAULT 1.0"),
        ("precisa_revisao", "INTEGER DEFAULT 0"),
    ]
    for col_name, col_def in novas_colunas:
        if col_name not in existing_cols:
            try:
                cursor.execute(f"ALTER TABLE documents ADD COLUMN {col_name} {col_def}")
            except Exception:
                pass
    conn.commit()
    count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    logger.info(f"Banco vetorial SQLite pronto em {DB_PATH}. Documentos indexados: {count}")
    conn.close()

VALID_CATEGORIES = ("Vocabulário", "Gramática", "História", "Mitologia", "Toponímia", "Geral")

def classificar_heuristico_regex(texto: str) -> tuple[str, float]:
    """Classifica chunk na taxonomia oficial de 6 categorias via heurística determinística."""
    txt = texto.lower()
    if re.search(
        r'\b(gram[aá]tica|sintaxe|morfolo|conjuga|prefixo|sufixo|pronome|posposi|part[ií]cula|'
        r'flex[aã]o|adjetiv|substantiv|verbo|transitividade|sintagma|ergativ|incorporação|marcador)\b',
        txt
    ):
        return "Gramática", 0.85
    if re.search(
        r'\b(vocabul[aá]rio|dicion[aá]rio|gloss[aá]rio|l[eé]xico|significa|tradu[çc]|termo[s]?\s*:\s*|'
        r'verbete|palavra[s]?\b|sin[oô]nimo|nomenclatura|lexema|entrada)\b',
        txt
    ):
        return "Vocabulário", 0.85
    if re.search(
        r'\b(tup[aã]|curupira|anhang[aá]|jaci|caipora|boitat[aá]|mitolog|lenda|cosmolog|ritual|'
        r'paj[eé]|pajelan|xam[aã]|cren[çc]a|sobrenatural|esp[ií]rito|jurupari|monan|sum[eé])\b',
        txt
    ):
        return "Mitologia", 0.85
    if re.search(
        r'\b(topon[ií]mia|top[oô]nimo|rio\s+[a-z]+|igarap[eé]|paran[aá]|itapema|pindorama|'
        r'serra\s+[a-z]+|ilha\s+[a-z]+|aldeia\s+[a-z]+|lugar|regi[aã]o|acidente\s+geogr[aá]fico|localidade)\b',
        txt
    ):
        return "Toponímia", 0.85
    if re.search(
        r'\b(hist[oó]ria|hans\s+staden|thevet|jean\s+de\s+l[eé]ry|anchieta|n[oó]brega|poti|camar[aã]o|'
        r's[eé]culo\s+(xvi|xvii|xviii)|colonial|coloniza[çc]|guerra|jesu[ií]ta|cronista|expedi[çc]|capitania)\b',
        txt
    ):
        return "História", 0.85
    return "Geral", 0.70

def save_chunks_with_provenance(chunks_to_save: List[Dict[str, Any]], embeddings: List[Any]):
    """Persiste chunks garantindo deduplicação por hash e integridade de proveniência."""
    max_retries = 5
    for attempt in range(max_retries):
        try:
            conn = _get_db_connection()
            for i, c in enumerate(chunks_to_save):
                emb_json = json.dumps(embeddings[i]) if embeddings[i] else None
                cat, cat_conf = classificar_heuristico_regex(c["document"])
                meta_dict = {
                    "filename": c["filename"],
                    "file_hash": c["file_hash"],
                    "content_hash": c["content_hash"],
                    "page": c["page"],
                    "chunk_index": c["chunk_index"],
                    "ocr_conf_mean": c["ocr_conf_mean"],
                    "ocr_conf_min": c["ocr_conf_min"],
                    "metodo_extracao": c["metodo_extracao"],
                    "sanity_reason": c["sanity_reason"],
                    "categoria": cat,
                }
                meta_json = json.dumps(meta_dict, ensure_ascii=False)
                conn.execute("""
                    INSERT INTO documents (
                        id, document, embedding, metadata, precisa_revisao, confianca, metodo_classificacao, categoria, category_extracted
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
                    ON CONFLICT(id) DO UPDATE SET
                        document=excluded.document,
                        embedding=excluded.embedding,
                        metadata=excluded.metadata,
                        precisa_revisao=excluded.precisa_revisao,
                        confianca=excluded.confianca,
                        categoria=excluded.categoria,
                        metodo_classificacao=excluded.metodo_classificacao,
                        category_extracted=1
                """, (
                    c["chunk_id"],
                    c["document"],
                    emb_json,
                    meta_json,
                    c["precisa_revisao"],
                    c["ocr_conf_mean"] / 100.0 if c["metodo_extracao"] == "ocr" else cat_conf,
                    "ocr_heuristico" if c["metodo_extracao"] == "ocr" else "heuristico",
                    cat
                ))
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
            cache_path = os.environ.get("FASTEMBED_CACHE_PATH", os.path.expanduser("~/.cache/huggingface/fastembed"))
            logger.info(f"Carregando modelo FastEmbed ONNX (cache={cache_path})...")
            _embedder_model = TextEmbedding(
                model_name="sentence-transformers/all-MiniLM-L6-v2",
                cache_dir=cache_path,
            )
        except Exception as e:
            logger.warning(f"FastEmbed indisponível ({e}). Embeddings não serão gerados offline.")
    return _embedder_model

def embed_texts(texts: List[str]) -> List[Any]:
    model = get_worker_embedder()
    if not model or not texts:
        return [[0.0] * EMBEDDING_DIM for _ in texts]
    try:
        embeddings = list(model.embed(texts))
        return [emb.tolist() for emb in embeddings]
    except Exception as e:
        logger.warning(f"Erro gerando embeddings FastEmbed: {e}")
        return [[0.0] * EMBEDDING_DIM for _ in texts]

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


# ── RASTERIZAÇÃO DE PÁGINA (300 DPI VIA PYPDFIUM2 / FALLBACK) ─────────────────

def render_page_300dpi(pdf_path: Path, page_index: int):
    """Renderiza a página a 300 DPI usando pypdfium2."""
    pdfium = _get_pypdfium2()
    if pdfium is not None:
        try:
            doc = pdfium.PdfDocument(str(pdf_path))
            page = doc[page_index]
            # Escala para 300 DPI: 300 / 72 = 4.16666
            pil_img = page.render(scale=300.0 / 72.0).to_pil()
            return pil_img
        except Exception as e:
            logger.warning(f"Falha na renderização pypdfium2 pág {page_index+1}: {e}")

    # Fallback: tenta extrair imagem embutida via PyPDF2
    pypdf2 = _get_pypdf2()
    _, _, Image_lib = _get_tesseract_and_pil()
    if pypdf2 and Image_lib:
        try:
            with open(pdf_path, "rb") as f:
                reader = pypdf2.PdfReader(f)
                page = reader.pages[page_index]
                for img_obj in page.images:
                    return Image_lib.open(io.BytesIO(img_obj.data))
        except Exception as e:
            logger.warning(f"Fallback PyPDF2 imagem falhou pág {page_index+1}: {e}")
    return None


# ── PIPELINE PRINCIPAL DE PROCESSAMENTO DE PDF ────────────────────────────────

def process_pdf(
    pdf_path: Path,
    file_hash: str,
    progress: dict,
    limit_pages: Optional[int] = None,
    reprocess_all: bool = False,
    dry_run: bool = False
) -> Dict[str, Any]:
    filename = pdf_path.name
    prog_key = file_hash
    last_page = 0 if reprocess_all else progress.get(prog_key, {}).get("last_page", 0)

    mode_label = "[DRY-RUN] " if dry_run else ""
    logger.info(f"\n{'='*70}")
    logger.info(f"{mode_label}[PDF] Processando: {filename} ({pdf_path.stat().st_size / 1024 / 1024:.2f} MB)")
    if last_page > 0:
        logger.info(f"Retomando da página {last_page + 1}...")

    pypdf2 = _get_pypdf2()
    if pypdf2 is None:
        logger.error(f"PyPDF2 não disponível para abrir {filename}")
        return {"error": "PyPDF2 missing"}

    try:
        with open(pdf_path, "rb") as f:
            reader = pypdf2.PdfReader(f)
            total_pages = len(reader.pages)
    except Exception as e:
        logger.error(f"Não foi possível abrir {filename}: {e}")
        return {"error": str(e)}

    # Limpeza atômica de chunks legados anteriores para este PDF se estiver reprocessando
    if reprocess_all and not dry_run:
        try:
            conn = _get_db_connection()
            conn.execute(
                "DELETE FROM documents WHERE metadata LIKE ? OR metadata LIKE ? OR id LIKE ?",
                (f'%"{filename}"%', f'%"{file_hash}"%', f"{file_hash[:12]}_%")
            )
            conn.commit()
            conn.close()
            logger.info(f"  [DB] Chunks legados anteriores de {filename} limpos para remigração completa.")
        except Exception as e:
            logger.warning(f"  [DB] Falha ao limpar chunks antigos de {filename}: {e}")

    max_page_to_process = total_pages
    if limit_pages is not None:
        max_page_to_process = min(total_pages, last_page + limit_pages)

    logger.info(f"Total de páginas: {total_pages} | Processando até a página: {max_page_to_process}")

    stats = {
        "pages_processed": 0,
        "pages_digital": 0,
        "pages_ocr": 0,
        "pages_failed": 0,
        "chunks_generated": 0,
        "chunks_flagged_review": 0,
        "duplicates_skipped": 0,
        "near_duplicates_skipped": 0,
        "ocr_confidences": [],
    }

    known_content_hashes = set()
    known_shingles: List[set] = []
    pending_chunks_to_save: List[Dict[str, Any]] = []

    for page_num in range(last_page, max_page_to_process):
        page_index = page_num
        page_number_human = page_num + 1
        page_text = ""
        ocr_conf_mean = 100.0
        ocr_conf_min = 100.0
        used_ocr = False

        try:
            # 1. Tenta extrair texto digital direto do PDF
            try:
                with open(pdf_path, "rb") as f:
                    reader = pypdf2.PdfReader(f)
                    page = reader.pages[page_index]
                    page_text = (page.extract_text() or "").strip()
            except Exception as e:
                logger.warning(f"  Erro extraindo texto digital da pág {page_number_human}: {e}")
                page_text = ""

            # 2. Se texto digital for escasso (< 120 chars), aciona o pipeline de OCR a 300 DPI
            if len(page_text) < MIN_PAGE_CHARS_DIGITAL:
                used_ocr = True
                logger.info(f"  [Pág {page_number_human}] Texto digital escasso ({len(page_text)} chars). Acionando OCR 300 DPI...")
                pil_img = render_page_300dpi(pdf_path, page_index)
                if pil_img is not None:
                    # Pré-processamento OpenCV (orientação, deskew, denoise, Otsu)
                    processed_img, angle, metrics = preprocess_image_for_ocr(pil_img)
                    # Tesseract OCR com dicionário Tupi e captura de confiança
                    page_text, ocr_conf_mean, ocr_conf_min, _ = ocr_image_with_confidence(processed_img, psm_mode=3)
                    stats["pages_ocr"] += 1
                    stats["ocr_confidences"].append(ocr_conf_mean)
                    logger.info(
                        f"    OCR Concluído: {len(page_text)} chars extraídos | Conf Média: {ocr_conf_mean:.1f}% (Min: {ocr_conf_min:.1f}%) | Skew: {angle:.1f}°"
                    )
                else:
                    logger.warning(f"    Não foi possível renderizar imagem da página {page_number_human}.")
            else:
                stats["pages_digital"] += 1

            stats["pages_processed"] += 1

            # 3. Chunking linguístico consciente e deduplicação
            page_chunks = chunk_text_linguistic(
                text=page_text,
                page_num=page_number_human,
                file_hash=file_hash,
                filename=filename,
                ocr_conf_mean=ocr_conf_mean,
                ocr_conf_min=ocr_conf_min,
                metodo_extracao="ocr" if used_ocr else "digital_text",
            )

            for chunk_obj in page_chunks:
                # 1. Deduplicação estrita por hash de conteúdo normalizado
                chash = chunk_obj["content_hash"]
                if chash in known_content_hashes:
                    stats["duplicates_skipped"] += 1
                    continue

                # 2. Deduplicação por similaridade (near-duplicates / cabeçalhos repetidos)
                c_shingles = compute_shingles(chunk_obj["document"])
                if is_near_duplicate(c_shingles, known_shingles, threshold=0.82):
                    stats["near_duplicates_skipped"] += 1
                    continue

                known_shingles.append(c_shingles)
                known_content_hashes.add(chash)

                if chunk_obj["precisa_revisao"] == 1:
                    stats["chunks_flagged_review"] += 1

                pending_chunks_to_save.append(chunk_obj)
                stats["chunks_generated"] += 1

            # 4. Salva em lotes de 20 chunks para otimizar I/O e RAM
            if len(pending_chunks_to_save) >= 20:
                if not dry_run:
                    texts = [c["document"] for c in pending_chunks_to_save]
                    embeddings = embed_texts(texts)
                    save_chunks_with_provenance(pending_chunks_to_save, embeddings)
                    logger.info(f"  [DB] {len(pending_chunks_to_save)} chunks persistidos no SQLite (Pág {page_number_human}).")
                else:
                    logger.info(f"  [DRY-RUN] Simulado lote de {len(pending_chunks_to_save)} chunks (sem escrita).")
                pending_chunks_to_save = []

            # 5. Salva progresso incremental a cada 10 páginas
            if page_number_human % 10 == 0:
                if not dry_run:
                    progress[prog_key] = {"last_page": page_number_human, "total_pages": total_pages}
                    save_progress(progress)
                logger.info(f"  [Progresso] {page_number_human}/{total_pages} páginas processadas...")

        except Exception as page_err:
            logger.warning(f"  [Pág {page_number_human}] Exceção não fatal capturada: {page_err}. Continuando...")
            stats["pages_failed"] += 1

    # Salva chunks restantes do buffer
    if pending_chunks_to_save:
        if not dry_run:
            texts = [c["document"] for c in pending_chunks_to_save]
            embeddings = embed_texts(texts)
            save_chunks_with_provenance(pending_chunks_to_save, embeddings)
            logger.info(f"  [DB] Últimos {len(pending_chunks_to_save)} chunks persistidos no SQLite.")
        else:
            logger.info(f"  [DRY-RUN] Simulado lote final de {len(pending_chunks_to_save)} chunks.")

    is_done = (max_page_to_process >= total_pages)
    if not dry_run:
        progress[prog_key] = {
            "last_page": max_page_to_process,
            "total_pages": total_pages,
            "done": is_done,
            "last_updated": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        save_progress(progress)

    avg_conf = sum(stats["ocr_confidences"]) / len(stats["ocr_confidences"]) if stats["ocr_confidences"] else 100.0
    logger.info(f"\n[RESUMO] Final para {filename}:")
    logger.info(f"   Páginas processadas: {stats['pages_processed']} (Digital={stats['pages_digital']}, OCR={stats['pages_ocr']}, Falhas={stats['pages_failed']})")
    logger.info(f"   Confiança média do OCR: {avg_conf:.1f}%")
    logger.info(f"   Chunks gerados: {stats['chunks_generated']} (Revisão={stats['chunks_flagged_review']}, Duplicatas Descartadas={stats['duplicates_skipped']}, Near-Dups={stats['near_duplicates_skipped']})")

    return stats


def main():
    parser = argparse.ArgumentParser(description="TupiLingo PDF Ingestion Worker com OCR 300 DPI e Chunking Linguístico")
    parser.add_argument("--pdf", type=str, default=None, help="Processa apenas um PDF específico")
    parser.add_argument("--limit-pages", type=int, default=None, help="Limita o número de páginas para teste")
    parser.add_argument("--reprocess-all", action="store_true", help="Força reprocessamento de páginas já processadas")
    parser.add_argument("--dry-run", action="store_true", help="Modo simulação: processa e valida métricas sem persistir no banco")
    parser.add_argument("--continuous", action="store_true", help="Roda em loop contínuo")
    args = parser.parse_args()

    if not args.dry_run:
        init_db()

    if not PDFS_DIR.exists():
        logger.error(f"Diretório de PDFs não encontrado: {PDFS_DIR}")
        return

    progress = load_progress()

    if args.pdf:
        target_path = PDFS_DIR / args.pdf
        if not target_path.exists():
            logger.error(f"PDF não encontrado: {target_path}")
            return
        file_hash = get_file_hash(target_path)
        process_pdf(target_path, file_hash, progress, limit_pages=args.limit_pages, reprocess_all=args.reprocess_all, dry_run=args.dry_run)
        return

    # Processamento de todos os PDFs do diretório
    pdfs = sorted(PDFS_DIR.glob("*.pdf"), key=lambda p: p.stat().st_size)
    logger.info(f"Encontrados {len(pdfs)} PDFs em {PDFS_DIR}")

    all_telemetry = {}
    total_start = time.time()

    for idx, pdf_path in enumerate(pdfs, 1):
        t0 = time.time()
        file_hash = get_file_hash(pdf_path)
        if not args.reprocess_all and progress.get(file_hash, {}).get("done"):
            logger.info(f"[{idx}/{len(pdfs)}] Pulando {pdf_path.name} (já processado).")
            continue

        logger.info(f"\n[{idx}/{len(pdfs)}] Iniciando processamento de {pdf_path.name}...")
        try:
            stats = process_pdf(
                pdf_path, file_hash, progress,
                limit_pages=args.limit_pages,
                reprocess_all=args.reprocess_all,
                dry_run=args.dry_run
            )
            elapsed = time.time() - t0
            stats["duration_s"] = round(elapsed, 2)
            all_telemetry[pdf_path.name] = stats
        except Exception as e:
            elapsed = time.time() - t0
            logger.error(f"Erro ao processar {pdf_path.name}: {e}. Continuando com os demais PDFs da fila...")
            traceback.print_exc()
            all_telemetry[pdf_path.name] = {
                "error": str(e),
                "duration_s": round(elapsed, 2),
                "pages_processed": 0,
                "chunks_generated": 0,
            }

    total_elapsed = time.time() - total_start

    # Exibe Relatório Consolidado de Telemetria
    logger.info("\n" + "=" * 105)
    logger.info(f"RELATÓRIO CONSOLIDADO DE REMIGRAÇÃO DO ACERVO ({len(pdfs)} PDFs em {total_elapsed:.1f}s)")
    logger.info("=" * 105)
    logger.info(f"{'PDF':<45} | {'Tempo':<7} | {'Págs':<6} | {'Digital':<7} | {'OCR':<5} | {'Chunks':<6} | {'Near-Dup':<8} | {'Status'}")
    logger.info("-" * 105)
    for fname, d in all_telemetry.items():
        if "error" in d:
            logger.info(f"{fname[:45]:<45} | {d.get('duration_s',0):<6.1f}s | {'ERR':<6} | {'-':<7} | {'-':<5} | {0:<6} | {'-':<8} | ERRO: {d['error'][:25]}")
        else:
            status_str = "OK" if d.get("pages_failed", 0) == 0 else f"{d['pages_failed']} falhas"
            logger.info(
                f"{fname[:45]:<45} | {d.get('duration_s',0):<6.1f}s | {d.get('pages_processed',0):<6} | "
                f"{d.get('pages_digital',0):<7} | {d.get('pages_ocr',0):<5} | {d.get('chunks_generated',0):<6} | "
                f"{d.get('near_duplicates_skipped',0):<8} | {status_str}"
            )
    logger.info("=" * 105)
    logger.info("Processamento de PDFs finalizado.")


if __name__ == "__main__":
    main()
