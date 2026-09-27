"""
Motor de Exportação Forense Multi-Formato (Etapa 12).

Gera representações arquivísticas padronizadas e interoperáveis:
- Markdown estruturado (com frontmatter de metadados forenses)
- JSON e JSONL completos
- TXT puro
- CSV / Parquet tabular em nível de token
- ALTO XML (padrão Library of Congress para OCR histórico)
- PAGE XML (padrão PRImA Research)
- HTML anotado interativo com tooltips de proveniência e confiança por palavra
"""

from __future__ import annotations

import csv
import html
import json
import logging
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from pydantic import BaseModel

from ocr_pipeline.core.provenance import PageAuditTrail, TokenProvenance

logger = logging.getLogger("ocr_pipeline.export_engine")


class ForensicExportBundle(BaseModel):
    """Metadados e caminhos dos arquivos exportados para uma página."""

    page_num: int
    markdown_path: str | None = None
    json_path: str | None = None
    jsonl_path: str | None = None
    txt_path: str | None = None
    csv_path: str | None = None
    alto_xml_path: str | None = None
    page_xml_path: str | None = None
    annotated_html_path: str | None = None


class ForensicMultiExporter:
    """Exportador multi-formato para pipelines arquivísticas."""

    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def export_all(
        self,
        page_num: int,
        transcription_text: str,
        tokens: list[TokenProvenance],
        diagnostic_meta: dict[str, Any] | None = None,
        audit_trail: PageAuditTrail | None = None,
    ) -> ForensicExportBundle:
        """Exporta a página em todos os formatos arquivísticos mandatários."""
        bundle = ForensicExportBundle(page_num=page_num)
        base_name = f"page_{page_num:04d}"

        # 1. TXT
        txt_path = self.output_dir / f"{base_name}.txt"
        self.export_txt(transcription_text, txt_path)
        bundle.txt_path = str(txt_path)

        # 2. Markdown com Frontmatter
        md_path = self.output_dir / f"{base_name}.md"
        self.export_markdown(page_num, transcription_text, diagnostic_meta, md_path)
        bundle.markdown_path = str(md_path)

        # 3. JSON completo
        json_path = self.output_dir / f"{base_name}.json"
        self.export_json(page_num, transcription_text, tokens, diagnostic_meta, json_path)
        bundle.json_path = str(json_path)

        # 4. JSONL por token
        jsonl_path = self.output_dir / f"{base_name}.tokens.jsonl"
        self.export_jsonl(tokens, jsonl_path)
        bundle.jsonl_path = str(jsonl_path)

        # 5. CSV Tabular
        csv_path = self.output_dir / f"{base_name}_tokens.csv"
        self.export_csv(tokens, csv_path)
        bundle.csv_path = str(csv_path)

        # 6. ALTO XML
        alto_path = self.output_dir / f"{base_name}_alto.xml"
        self.export_alto_xml(page_num, tokens, alto_path)
        bundle.alto_xml_path = str(alto_path)

        # 7. PAGE XML
        page_xml_path = self.output_dir / f"{base_name}_page.xml"
        self.export_page_xml(page_num, tokens, page_xml_path)
        bundle.page_xml_path = str(page_xml_path)

        # 8. HTML Anotado
        html_path = self.output_dir / f"{base_name}_annotated.html"
        self.export_annotated_html(page_num, tokens, html_path)
        bundle.annotated_html_path = str(html_path)

        return bundle

    def export_txt(self, text: str, out_path: Path):
        """Grava texto puro UTF-8."""
        out_path.write_text(text, encoding="utf-8")

    def export_markdown(
        self,
        page_num: int,
        text: str,
        diagnostic_meta: dict[str, Any] | None,
        out_path: Path,
    ):
        """Exporta Markdown com metadados forenses em frontmatter YAML."""
        meta_yaml = ["---", f"page: {page_num}", "pipeline: TupiLingo OCR Forense v3.0"]
        if diagnostic_meta:
            for k, v in diagnostic_meta.items():
                meta_yaml.append(f"{k}: {v}")
        meta_yaml.append("---\n")
        content = "\n".join(meta_yaml) + f"# Página {page_num}\n\n" + text + "\n"
        out_path.write_text(content, encoding="utf-8")

    def export_json(
        self,
        page_num: int,
        text: str,
        tokens: list[TokenProvenance],
        diagnostic_meta: dict[str, Any] | None,
        out_path: Path,
    ):
        """Exporta documento JSON estruturado."""
        doc = {
            "page": page_num,
            "pipeline": "TupiLingo OCR Forense v3.0",
            "diagnostics": diagnostic_meta or {},
            "transcription": text,
            "tokens": [t.model_dump() for t in tokens],
        }
        out_path.write_text(json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8")

    def export_jsonl(self, tokens: list[TokenProvenance], out_path: Path):
        """Exporta tokens um por linha em JSONL."""
        with open(out_path, "w", encoding="utf-8") as f:
            f.writelines(tok.model_dump_json() + "\n" for tok in tokens)

    def export_csv(self, tokens: list[TokenProvenance], out_path: Path):
        """Exporta métricas tabulares dos tokens."""
        fieldnames = [
            "text",
            "confidence",
            "engine",
            "branch",
            "x1",
            "y1",
            "x2",
            "y2",
            "rag_verified",
            "is_rollback",
        ]
        with open(out_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for tok in tokens:
                writer.writerow(
                    {
                        "text": tok.cleaned_text,
                        "confidence": f"{tok.confidence_fused:.4f}",
                        "engine": tok.engine_origin,
                        "branch": tok.preprocessing_branch,
                        "x1": tok.bbox.x1,
                        "y1": tok.bbox.y1,
                        "x2": tok.bbox.x2,
                        "y2": tok.bbox.y2,
                        "rag_verified": tok.rag_verified,
                        "is_rollback": tok.is_rollback,
                    }
                )

    def export_alto_xml(
        self,
        page_num: int,
        tokens: list[TokenProvenance],
        out_path: Path,
        width: int = 2400,
        height: int = 3300,
    ):
        """Exporta ALTO XML v4 (Library of Congress OCR Schema)."""
        alto = ET.Element("alto", xmlns="http://www.loc.gov/standards/alto/ns-v4#")
        description = ET.SubElement(alto, "Description")
        measurement = ET.SubElement(description, "MeasurementUnit")
        measurement.text = "pixel"

        layout = ET.SubElement(alto, "Layout")
        page = ET.SubElement(
            layout,
            "Page",
            ID=f"page_{page_num}",
            PHYSICAL_IMG_NR=str(page_num),
            WIDTH=str(width),
            HEIGHT=str(height),
        )
        print_space = ET.SubElement(
            page, "PrintSpace", HPOS="0", VPOS="0", WIDTH=str(width), HEIGHT=str(height)
        )
        text_block = ET.SubElement(print_space, "TextBlock", ID=f"block_{page_num}_1")
        text_line = ET.SubElement(text_block, "TextLine", ID=f"line_{page_num}_1")

        for idx, tok in enumerate(tokens):
            w = tok.bbox.x2 - tok.bbox.x1
            h = tok.bbox.y2 - tok.bbox.y1
            ET.SubElement(
                text_line,
                "String",
                ID=f"word_{page_num}_{idx}",
                CONTENT=tok.cleaned_text,
                HPOS=str(tok.bbox.x1),
                VPOS=str(tok.bbox.y1),
                WIDTH=str(w),
                HEIGHT=str(h),
                WC=f"{tok.confidence_fused:.3f}",
            )

        tree = ET.ElementTree(alto)
        tree.write(out_path, encoding="utf-8", xml_declaration=True)

    def export_page_xml(
        self,
        page_num: int,
        tokens: list[TokenProvenance],
        out_path: Path,
        width: int = 2400,
        height: int = 3300,
    ):
        """Exporta PAGE XML (PRImA Research standard)."""
        p_xml = ET.Element(
            "PcGts",
            xmlns="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15",
        )
        page = ET.SubElement(
            p_xml,
            "Page",
            imageFilename=f"page_{page_num:04d}.png",
            imageWidth=str(width),
            imageHeight=str(height),
        )
        region = ET.SubElement(page, "TextRegion", id=f"r_{page_num}_1")
        ET.SubElement(
            region,
            "Coords",
            points=f"0,0 {width},0 {width},{height} 0,{height}",
        )

        for idx, tok in enumerate(tokens):
            w_elem = ET.SubElement(region, "Word", id=f"w_{page_num}_{idx}")
            ET.SubElement(
                w_elem,
                "Coords",
                points=f"{tok.bbox.x1},{tok.bbox.y1} {tok.bbox.x2},{tok.bbox.y1} {tok.bbox.x2},{tok.bbox.y2} {tok.bbox.x1},{tok.bbox.y2}",
            )
            text_equiv = ET.SubElement(w_elem, "TextEquiv", conf=f"{tok.confidence_fused:.3f}")
            ET.SubElement(text_equiv, "Unicode").text = tok.cleaned_text

        tree = ET.ElementTree(p_xml)
        tree.write(out_path, encoding="utf-8", xml_declaration=True)

    def export_annotated_html(
        self,
        page_num: int,
        tokens: list[TokenProvenance],
        out_path: Path,
    ):
        """Exporta HTML interativo com tooltips de confiança e coloração forense."""
        token_spans = []
        for tok in tokens:
            # Cor baseada na confiança
            if tok.confidence_fused >= 0.90:
                bg = "rgba(46, 204, 113, 0.25)"
                border = "#27ae60"
            elif tok.confidence_fused >= 0.75:
                bg = "rgba(241, 196, 15, 0.25)"
                border = "#f39c12"
            else:
                bg = "rgba(231, 76, 60, 0.25)"
                border = "#c0392b"

            safe_text = html.escape(tok.cleaned_text)
            tip = f"Conf: {tok.confidence_fused*100:.1f}% | Motor: {tok.engine_origin} | Branch: {tok.preprocessing_branch}"
            span = (
                f'<span class="tok" style="background:{bg}; border-bottom: 2px solid {border};" '
                f'title="{tip}">{safe_text}</span>'
            )
            token_spans.append(span)

        body_content = " ".join(token_spans)
        html_doc = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>TupiLingo OCR Forense - Página {page_num}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 2rem; line-height: 2.0; font-size: 1.15rem; }}
    .container {{ max-width: 900px; margin: 0 auto; background: #1e293b; padding: 2.5rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }}
    h1 {{ color: #38bdf8; font-size: 1.6rem; border-bottom: 1px solid #334155; padding-bottom: 0.8rem; margin-top: 0; }}
    .tok {{ padding: 2px 4px; border-radius: 4px; cursor: pointer; transition: all 0.15s ease; }}
    .tok:hover {{ filter: brightness(1.2); outline: 2px solid #38bdf8; }}
    .legend {{ margin-top: 2rem; padding: 1rem; background: #0f172a; border-radius: 8px; font-size: 0.9rem; display: flex; gap: 1.5rem; }}
    .badge {{ display: inline-block; width: 12px; height: 12px; border-radius: 3px; margin-right: 6px; }}
  </style>
</head>
<body>
  <div class="container">
    <h1>TupiLingo Forense v3.0 — Página {page_num}</h1>
    <div class="content">
      {body_content}
    </div>
    <div class="legend">
      <div><span class="badge" style="background:#27ae60"></span> Confiança Alta (≥ 90%)</div>
      <div><span class="badge" style="background:#f39c12"></span> Confiança Média (75%–89%)</div>
      <div><span class="badge" style="background:#c0392b"></span> Confiança Baixa (&lt; 75%)</div>
    </div>
  </div>
</body>
</html>
"""
        out_path.write_text(html_doc, encoding="utf-8")
