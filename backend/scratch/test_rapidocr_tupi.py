import time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from rapidocr_onnxruntime import RapidOCR
import symspellpy

print("1. Testing RapidOCR import & initialization on CPU...")
t0 = time.time()
engine = RapidOCR()
init_time = time.time() - t0
print(f"RapidOCR initialized in {init_time:.2f}s")

# Create a clean synthetic image with Tupi diacritics
img_w, img_h = 800, 200
img = Image.new("RGB", (img_w, img_h), color=(255, 255, 255))
draw = ImageDraw.Draw(img)

# Text required by prompt: morubixaba, oka, peẽ, iandé
test_text = "morubixaba oka peẽ iandé"
# Draw using default or basic font
draw.text((30, 40), test_text, fill=(0, 0, 0))
draw.text((30, 100), "Dicionário Tupi Antigo: peẽ iandé morubixaba oka", fill=(0, 0, 0))

# Convert to numpy array
img_np = np.array(img)

print("2. Running OCR recognition on test image...")
t1 = time.time()
result, elapse_list = engine(img_np)
ocr_time = time.time() - t1

print(f"OCR inference completed in {ocr_time:.3f}s")
print(f"Elapse details: {elapse_list}")
print(f"Raw Result:")
if result:
    for item in result:
        bbox, text, conf = item[0], item[1], item[2]
        print(f"  Detected: '{text}' (conf: {float(conf):.4f})")
else:
    print("  No text detected!")

print("\n3. Testing SymSpell initialization...")
sym_spell = symspellpy.SymSpell(max_dictionary_edit_distance=2, prefix_length=7)
print("SymSpell initialized successfully.")
