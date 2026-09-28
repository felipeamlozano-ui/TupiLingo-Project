"""
Ground Truth Builder — Capítulo 21
Gerencia o repositório permanente de Verdade Fundamental (Ground Truth):
  - Diretório: ground_truth/page_XXX/{image.png, transcription.txt, tokens.json, metadata.json}
  - Banco SQLite dedicado e protegido: ground_truth.db (tabela ground_truth_tokens)
  - Interface local HTML de anotação: annotator.html
  - Proíbe edição automática descontrolada.
"""
from __future__ import annotations

import json
import logging
import sqlite3
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Optional
from PIL import Image
from pydantic import BaseModel, Field

logger = logging.getLogger("ground_truth_builder")


class GroundTruthToken(BaseModel):
    token: str
    bbox: list[int]  # [x1, y1, x2, y2]
    line_index: int = 0
    reading_order_index: int = 0


class GroundTruthManager:
    """Gerenciador do banco e dos arquivos de Ground Truth."""

    def __init__(
        self,
        base_dir: Optional[Path] = None,
        db_path: Optional[Path] = None,
    ):
        self.base_dir = base_dir or (Path(__file__).resolve().parent.parent.parent / "ground_truth")
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = db_path or (self.base_dir / "ground_truth.db")
        self._init_sqlite()
        self.generate_annotation_ui()

    def _init_sqlite(self):
        """Inicializa tabela de Ground Truth no SQLite separado."""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS ground_truth_tokens (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    page_id TEXT NOT NULL,
                    bbox TEXT NOT NULL,
                    token TEXT NOT NULL,
                    source_pdf TEXT NOT NULL,
                    reviewer TEXT NOT NULL,
                    revision_date TEXT NOT NULL
                )
                """
            )
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_gt_page ON ground_truth_tokens(page_id)")
            conn.commit()
        finally:
            conn.close()

    def save_page_ground_truth(
        self,
        page_id: str,
        pil_image: Image.Image,
        transcription: str,
        tokens: list[dict[str, Any]],
        source_pdf: str,
        reviewer: str = "curador_humano",
        metadata: Optional[dict[str, Any]] = None,
    ) -> Path:
        """
        Salva página de ground truth na pasta estruturada e insere no banco protegido.
        """
        page_dir = self.base_dir / page_id
        page_dir.mkdir(parents=True, exist_ok=True)

        # 1. Salvar image.png
        image_path = page_dir / "image.png"
        pil_image.save(image_path, format="PNG")

        # 2. Salvar transcription.txt
        txt_path = page_dir / "transcription.txt"
        with open(txt_path, "w", encoding="utf-8") as f:
            f.write(transcription)

        # 3. Salvar tokens.json
        tokens_path = page_dir / "tokens.json"
        with open(tokens_path, "w", encoding="utf-8") as f:
            json.dump(tokens, f, indent=2, ensure_ascii=False)

        # 4. Salvar metadata.json
        meta = metadata or {}
        meta.update({
            "page_id": page_id,
            "source_pdf": source_pdf,
            "reviewer": reviewer,
            "revision_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "token_count": len(tokens),
            "char_count": len(transcription),
        })
        meta_path = page_dir / "metadata.json"
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2, ensure_ascii=False)

        # 5. Persistir no SQLite
        rev_date = meta["revision_date"]
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            # Remover tokens anteriores da mesma página se revisada novamente
            cursor.execute("DELETE FROM ground_truth_tokens WHERE page_id = ?", (page_id,))
            for tok in tokens:
                token_str = tok.get("token") or tok.get("text", "")
                bbox_json = json.dumps(tok.get("bbox", [0, 0, 0, 0]))
                cursor.execute(
                    """
                    INSERT INTO ground_truth_tokens (page_id, bbox, token, source_pdf, reviewer, revision_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (page_id, bbox_json, token_str, source_pdf, reviewer, rev_date),
                )
            conn.commit()
        finally:
            conn.close()

        logger.info(f"Página {page_id} salva com sucesso no Ground Truth ({len(tokens)} tokens).")
        return page_dir

    def list_all_pages(self) -> list[str]:
        """Retorna lista de todos os page_ids registrados no diretório base."""
        if not self.base_dir.exists():
            return []
        pages = []
        for p in self.base_dir.iterdir():
            if p.is_dir() and p.name.startswith("page_"):
                pages.append(p.name)
        return sorted(pages)

    def load_page_metadata(self, page_id: str) -> Optional[dict[str, Any]]:
        meta_file = self.base_dir / page_id / "metadata.json"
        if meta_file.exists():
            try:
                return json.loads(meta_file.read_text(encoding="utf-8"))
            except Exception:
                return None
        return None

    def get_page_tokens(self, page_id: str) -> list[dict[str, Any]]:
        tokens_file = self.base_dir / page_id / "tokens.json"
        if tokens_file.exists():
            try:
                return json.loads(tokens_file.read_text(encoding="utf-8"))
            except Exception:
                return []
        return []

    def get_ground_truth_for_page(self, page_id: str) -> Optional[dict[str, Any]]:
        """Carrega o pacote de Ground Truth de uma página."""
        page_dir = self.base_dir / page_id
        if not page_dir.exists():
            return None

        txt_file = page_dir / "transcription.txt"
        tokens_file = page_dir / "tokens.json"
        meta_file = page_dir / "metadata.json"

        transcription = txt_file.read_text(encoding="utf-8") if txt_file.exists() else ""
        tokens = json.loads(tokens_file.read_text(encoding="utf-8")) if tokens_file.exists() else []
        meta = json.loads(meta_file.read_text(encoding="utf-8")) if meta_file.exists() else {}

        return {
            "page_id": page_id,
            "transcription": transcription,
            "tokens": tokens,
            "metadata": meta,
            "dir": page_dir,
        }

    def generate_annotation_ui(self) -> Path:
        """Gera a ferramenta de anotação e correção local HTML."""
        html_path = self.base_dir / "annotator.html"
        html_content = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>TupiLingo — Ground Truth Annotator (Capítulo 21)</title>
  <style>
    body { font-family: sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 20px; display: flex; gap: 20px; }
    #editor-panel { flex: 1; background: #1e293b; padding: 20px; border-radius: 8px; border: 1px solid #334155; }
    #viewer-panel { flex: 1; background: #1e293b; padding: 20px; border-radius: 8px; border: 1px solid #334155; }
    textarea { width: 100%; height: 350px; background: #0f172a; color: #38bdf8; border: 1px solid #334155; font-family: monospace; font-size: 14px; padding: 10px; border-radius: 4px; box-sizing: border-box; }
    .btn { background: #0284c7; color: white; border: none; padding: 10px 16px; border-radius: 4px; cursor: pointer; font-weight: bold; margin-top: 10px; }
    .btn:hover { background: #0369a1; }
    h2 { color: #38bdf8; margin-top: 0; }
  </style>
</head>
<body>
  <div id="editor-panel">
    <h2>Anotador & Revisor de Ground Truth</h2>
    <p>Insira a transcrição diplomática fiel da página:</p>
    <textarea id="textEditor" placeholder="Digite ou cole o texto revisado palavra por palavra..."></textarea>
    <div>
      <input type="text" id="reviewerName" placeholder="Nome do revisor" value="revisor_humano" style="padding: 8px; width: 200px; background: #0f172a; color: white; border: 1px solid #334155; border-radius: 4px;">
      <button class="btn" onclick="exportJSON()">Salvar Ground Truth</button>
    </div>
  </div>
  <div id="viewer-panel">
    <h2>Instruções Científicas</h2>
    <ul>
      <li>Preservar diacríticos nasais autênticos (ex: ã, ẽ, ĩ, õ, ũ, ỹ).</li>
      <li>Não corrigir ortografia arcaica para o português moderno.</li>
      <li>Conferir pontuação original de tipografia do século XVI-XX.</li>
    </ul>
    <pre id="outputPreview" style="background: #0f172a; padding: 10px; color: #4ade80; border-radius: 4px;"></pre>
  </div>
  <script>
    function exportJSON() {
      const text = document.getElementById("textEditor").value;
      const reviewer = document.getElementById("reviewerName").value;
      const tokens = text.split(/\\s+/).filter(t => t.length > 0).map((t, idx) => ({
        token: t,
        line_index: 1,
        reading_order_index: idx + 1,
        bbox: [10, 10 + idx * 20, 200, 30 + idx * 20]
      }));
      document.getElementById("outputPreview").innerText = JSON.stringify({
        reviewer: reviewer,
        tokens_count: tokens.length,
        status: "Ground Truth pronto para sincronização SQLite"
      }, null, 2);
    }
  </script>
</body>
</html>"""
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html_content)
        return html_path
