import pypdfium2 as pdfium
import cv2
import numpy as np
import json
import sqlite3
from pathlib import Path

# Connect to database to get known page confidences and samples across PDFs
conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Get representative pages from various PDFs
cursor.execute("""
    SELECT metadata, confianca, precisa_revisao 
    FROM documents 
    WHERE metadata IS NOT NULL
""")
rows = cursor.fetchall()
conn.close()

# Group pages by PDF
pdf_pages = {}
for meta_str, conf, precisa_rev in rows:
    try:
        meta = json.loads(meta_str)
        fname = meta.get("filename")
        p = meta.get("page", 1)
        ocr_c = meta.get("ocr_conf_mean", 100.0)
        met_ext = meta.get("metodo_extracao", "digital_text")
        if fname not in pdf_pages:
            pdf_pages[fname] = {}
        if p not in pdf_pages[fname]:
            pdf_pages[fname][p] = {
                "conf": ocr_c,
                "precisa_rev": precisa_rev,
                "metodo": met_ext
            }
    except Exception:
        continue

pdfs_dir = Path('backend/pdfs')
raw_metrics = {
    "lap_var": [],
    "contrast_rms": [],
    "entropy": [],
    "skew_deg": []
}

sampled_count = 0
for fname, pages in list(pdf_pages.items()):
    pdf_path = pdfs_dir / fname
    if not pdf_path.exists():
        continue
    try:
        pdf = pdfium.PdfDocument(str(pdf_path))
        # Take up to 5 pages per PDF
        sample_page_indices = sorted(list(pages.keys()))[:5]
        for p_num in sample_page_indices:
            idx = p_num - 1 # 0-indexed
            if idx < 0 or idx >= len(pdf):
                continue
            page = pdf[idx]
            pil_img = page.render(scale=150.0/72.0).to_pil()
            gray = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2GRAY)
            
            # 1. LapVar
            lap_v = float(cv2.Laplacian(gray, cv2.CV_64F).var())
            
            # 2. Contrast RMS
            contrast = float(np.std(gray))
            
            # 3. Entropy
            hist, _ = np.histogram(gray, bins=256, range=(0, 256), density=True)
            hist = hist[hist > 0]
            entropy = float(-np.sum(hist * np.log2(hist)))
            
            # 4. Skew
            _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
            coords = np.column_stack(np.where(thresh > 0))
            angle = 0.0
            if len(coords) > 50:
                rect = cv2.minAreaRect(coords)
                angle = rect[-1]
                if angle < -45:
                    angle = -(90 + angle)
                else:
                    angle = -angle
            skew_val = float(abs(angle))
            
            raw_metrics["lap_var"].append(lap_v)
            raw_metrics["contrast_rms"].append(contrast)
            raw_metrics["entropy"].append(entropy)
            raw_metrics["skew_deg"].append(skew_val)
            sampled_count += 1
            if sampled_count >= 120:
                break
    except Exception as e:
        print(f"Error on {fname}: {e}")
    if sampled_count >= 120:
        break

print(f"Sampled {sampled_count} pages across PDFs.")
calibration_params = {}
for k, vals in raw_metrics.items():
    arr = np.array(vals)
    p10 = float(np.percentile(arr, 10))
    p25 = float(np.percentile(arr, 25))
    p50 = float(np.percentile(arr, 50))
    p75 = float(np.percentile(arr, 75))
    p90 = float(np.percentile(arr, 90))
    calibration_params[k] = {
        "p10": round(p10, 2),
        "p25": round(p25, 2),
        "p50": round(p50, 2),
        "p75": round(p75, 2),
        "p90": round(p90, 2),
        "min": round(float(np.min(arr)), 2),
        "max": round(float(np.max(arr)), 2)
    }
    print(f"Metric {k:14s}: p10={p10:7.2f}, p50={p50:7.2f}, p90={p90:7.2f}, min={np.min(arr):7.2f}, max={np.max(arr):7.2f}")

with open("backend/scratch/calibration_params.json", "w", encoding="utf-8") as f:
    json.dump(calibration_params, f, indent=2)
print("Saved calibration parameters to backend/scratch/calibration_params.json")
