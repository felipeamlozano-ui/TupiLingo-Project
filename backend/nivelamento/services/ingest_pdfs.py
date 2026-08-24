"""
ingest_pdfs.py - Stub para compatibilidade.
O processamento real de PDFs agora e feito pelo pdf_worker.py (processo independente).
Este modulo nao usa mais ChromaDB.
"""
import logging

logger = logging.getLogger("nivelamento.ingest")


def ingest_new_pdfs() -> None:
    """
    Stub de compatibilidade. 
    O processamento de PDFs e feito pelo pdf_worker.py (veja dev.bat).
    """
    logger.info("ingest_new_pdfs() chamado. O processamento e feito pelo PDF Worker (pdf_worker.py).")
