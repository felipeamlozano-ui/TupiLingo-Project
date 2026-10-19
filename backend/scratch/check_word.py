import sys
import io
import pymupdf
import pytesseract
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
doc = pymupdf.open('backend/pdfs/Dicionário Tupi.pdf')

test_words = ['tatá', 'pirá', 'abá', 'itá', 'oká', 'gûyrá', 'tekó', 'aué', 'irũ', 'ka\'a', 'mba\'e', 'îagûara', 'tyb', 'pûer', 'oré', 'îandé']

# Check page 31 for abá
p31 = doc[30].get_pixmap(dpi=120) # 0-indexed 30 is page 31
img31 = Image.open(io.BytesIO(p31.tobytes('png'))).rotate(180)
txt31 = pytesseract.image_to_string(img31, lang='por')
print("Page 31 contains 'abá':", 'abá' in txt31.lower())
lines = [l for l in txt31.split('\n') if 'abá' in l.lower()]
print("Page 31 abá lines:", lines[:3])
