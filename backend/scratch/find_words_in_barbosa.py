import PyPDF2

pdf_path = r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf"
reader = PyPDF2.PdfReader(pdf_path)

print(f"Buscando 'morubixaba' e 'oka' nas {len(reader.pages)} páginas de Barbosa 1956...")

found_moru = []
found_oka = []

for i, page in enumerate(reader.pages):
    txt = page.extract_text() or ""
    txt_lower = txt.lower()
    if "morubixaba" in txt_lower or "morubixab" in txt_lower or "morubxat" in txt_lower:
        found_moru.append(i + 1)
    if " oka " in txt_lower or "oka-" in txt_lower or "-oka" in txt_lower or "oca " in txt_lower:
        found_oka.append(i + 1)

print(f"Páginas com 'morubixaba' em Barbosa 1956: {found_moru}")
print(f"Páginas com 'oka/oca' em Barbosa 1956: {found_oka[:15]}")
