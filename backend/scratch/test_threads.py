import sys
sys.path.insert(0, ".")
import time
import pypdfium2 as pdfium
from pathlib import Path
from ocr_pipeline.ocr_worker import OCRWorker

PDF_PATH = Path("pdfs/Dicionário Tupi.pdf")
doc = pdfium.PdfDocument(str(PDF_PATH))
page = doc[14] # page 15
img = page.render(scale=300.0 / 72.0).to_pil()

for threads in [4, 6, 8]:
    worker = OCRWorker(cpu_threads=threads)
    t0 = time.time()
    t_txt, t_c, _, _ = worker.run_tesseract(img)
    t_tess = time.time() - t0
    
    t0 = time.time()
    r_txt, r_c, _, _ = worker.run_rapidocr(img)
    t_rapid = time.time() - t0
    
    print(f"Threads: {threads:2d} | Tesseract: {t_tess:5.2f}s (conf {t_c}) | RapidOCR: {t_rapid:5.2f}s (conf {r_c}) | Total: {t_tess+t_rapid:5.2f}s")
