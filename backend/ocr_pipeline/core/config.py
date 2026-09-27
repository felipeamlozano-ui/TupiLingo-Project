"""
Configuração Global de Produção — TupiLingo OCR Forense v3.0
Definição rigorosa de parâmetros de execução, limites de hardware e limiares de qualidade.
"""
from pathlib import Path

from pydantic import BaseModel, Field

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
PDFS_DIR = BACKEND_DIR / "pdfs"
DB_PATH = BACKEND_DIR / "vector_store.db"
TUPI_WORDS_FILE = BACKEND_DIR / "tupi_user_words.txt"
LEXICON_DATA_FILE = BACKEND_DIR / "pedagogico" / "lexicon_data.py"
CACHE_DIR = BACKEND_DIR / "ocr_cache"
CHECKPOINTS_DIR = CACHE_DIR / "checkpoints"
EXPORTS_DIR = BACKEND_DIR / "ocr_exports"

CACHE_DIR.mkdir(parents=True, exist_ok=True)
CHECKPOINTS_DIR.mkdir(parents=True, exist_ok=True)
EXPORTS_DIR.mkdir(parents=True, exist_ok=True)

class HardwareConfig(BaseModel):
    cpu_threads: int = Field(default=6, description="Threads máximas para evitar saturação no Ryzen 5 5500U")
    tile_size: int = Field(default=256, description="Tamanho de tile para processamento de super-resolução e OCR")
    tile_overlap: int = Field(default=32, description="Sobreposição entre tiles adjacentes")
    max_process_memory_mb: int = Field(default=1500, description="Teto de segurança de memória para o processo")
    enable_memory_cleanup: bool = Field(default=True, description="Coleta forçada de lixo pós-página")

class DiagnosticConfig(BaseModel):
    laplacian_blur_threshold: float = Field(default=100.0, description="Limiar Laplaciano para aviso de blur")
    skew_max_angle: float = Field(default=15.0, description="Ângulo máximo aceitável para correção de deskew")
    bleed_through_diff_threshold: float = Field(default=0.20, description="Diferença percentual Otsu vs Sauvola para bleed")
    fft_noise_high_freq_cutoff: float = Field(default=0.85, description="Frequência de corte para análise espectral de ruído")

class OCRConfidenceThresholds(BaseModel):
    rapido: float = Field(default=98.0, description="Limiar para OCR Rápido / Digital")
    padrao: float = Field(default=94.0, description="Limiar para OCR Padrão")
    reforcado: float = Field(default=90.0, description="Limiar para Fase 1 Reforçado")
    atencao: float = Field(default=85.0, description="Limiar para Alerta de Atenção")
    revisao: float = Field(default=75.0, description="Limiar para Fila de Revisão Humana Obrigatória")

class OCREnsembleConfig(BaseModel):
    tesseract_psms: list[int] = Field(default=[3, 4, 6, 11], description="Modos PSM do Tesseract a testar")
    dpi_levels: list[int] = Field(default=[300, 450], description="Níveis de DPI para renderização forense")
    primary_engine: str = Field(default="rapidocr", description="Motor principal com maior acurácia no papel escaneado")
    secondary_engine: str = Field(default="tesseract", description="Motor secundário para preservação de diacríticos Tupi")

class LexicalConfig(BaseModel):
    max_edit_distance: int = Field(default=2, description="Distância máxima de Levenshtein")
    prefix_length: int = Field(default=7, description="Comprimento de prefixo para SymSpell")
    strict_tupi_safeguard: bool = Field(default=True, description="Impede que palavras Tupi sejam alteradas para português")
    preserve_casing: bool = Field(default=True, description="Preserva rigorosamente a caixa original (minúscula, Title, MAIÚSCULA)")

class ForensePipelineConfig(BaseModel):
    hardware: HardwareConfig = Field(default_factory=HardwareConfig)
    diagnostic: DiagnosticConfig = Field(default_factory=DiagnosticConfig)
    thresholds: OCRConfidenceThresholds = Field(default_factory=OCRConfidenceThresholds)
    ensemble: OCREnsembleConfig = Field(default_factory=OCREnsembleConfig)
    lexical: LexicalConfig = Field(default_factory=LexicalConfig)
    max_iterative_recovery_steps: int = Field(default=5, description="Iterações máximas para regiões com score < 90")
    sqlite_db_path: Path = DB_PATH
    tupi_words_file: Path = TUPI_WORDS_FILE
    lexicon_data_file: Path = LEXICON_DATA_FILE
    cache_dir: Path = CACHE_DIR
    checkpoints_dir: Path = CHECKPOINTS_DIR
    exports_dir: Path = EXPORTS_DIR

GLOBAL_CONFIG = ForensePipelineConfig()
