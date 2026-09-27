import cv2
import numpy as np
import pypdfium2 as pdfium
from pathlib import Path

def sauvola_threshold(gray, window_size=25, k=0.2, R=128):
    """
    Sauvola & Pietikäinen (2000) adaptive binarization for bleed-through and degraded documents.
    T = m * (1 + k * (s / R - 1))
    """
    if window_size % 2 == 0:
        window_size += 1
    # Use cv2.boxFilter for fast computation of local mean and variance
    mean = cv2.boxFilter(gray.astype(np.float32), cv2.CV_32F, (window_size, window_size))
    sq_mean = cv2.boxFilter((gray.astype(np.float32))**2, cv2.CV_32F, (window_size, window_size))
    variance = np.maximum(sq_mean - mean**2, 0)
    std = np.sqrt(variance)
    
    threshold = mean * (1.0 + k * (std / R - 1.0))
    binary = np.where(gray < threshold, 0, 255).astype(np.uint8)
    return binary

pdf_path = Path('backend/pdfs') / 'Dicionário Tupi.pdf'
pdf = pdfium.PdfDocument(str(pdf_path))
page = pdf[50]
pil_img = page.render(scale=150.0/72.0).to_pil()
gray = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2GRAY)

# Standard Otsu
_, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

# Sauvola
sauvola = sauvola_threshold(gray, window_size=31, k=0.25)

# Compare foreground ink percentage
otsu_ink = np.sum(otsu == 0) / otsu.size * 100
sauvola_ink = np.sum(sauvola == 0) / sauvola.size * 100

print(f"Otsu foreground ink: {otsu_ink:.2f}%")
print(f"Sauvola foreground ink: {sauvola_ink:.2f}%")
print(f"Bleed-through / background noise reduction: {otsu_ink - sauvola_ink:.2f}% cleaner!")
