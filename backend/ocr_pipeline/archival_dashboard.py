"""
Dashboard Arquivístico Interativo — Capítulo 16
Gera dashboard HTML local, página por página:
  - Visualização de imagem original, variante pré-processada e heatmap de confiança
  - Decomposição transparente dos componentes de confiança (c_ocr, c_vis, c_lex, c_rag, c_consensus)
  - Rastreamento de motores OCR utilizados, tempo de execução por página e uso de VRAM/RAM
  - Rotulação estrita de métricas: exibe "Confiança Proxy Heurística" a menos que haja Ground Truth (Capítulo 17).
"""
import json
from pathlib import Path
from typing import Any, Optional


class ArchivalDashboardGenerator:
    """Gerador do Dashboard HTML local para auditoria visual e arquivística."""

    def __init__(self, output_path: Optional[Path] = None):
        self.output_path = output_path or (
            Path(__file__).resolve().parent.parent / "ocr_cache" / "dashboard.html"
        )
        self.output_path.parent.mkdir(parents=True, exist_ok=True)

    def generate(
        self,
        pages_records: list[dict[str, Any]],
        title: str = "TupiLingo OCR v5 — Dashboard Arquivístico",
        ground_truth_available: bool = False,
    ) -> Path:
        """
        Renderiza o template HTML estático e autocontido com os dados do lote.
        """
        records_json = json.dumps(pages_records, ensure_ascii=False)

        metric_label = "CER / WER Real (Ground Truth Homologado)" if ground_truth_available else "Confiança Proxy Heurística (v5)"
        metric_badge = "Homologado Ground Truth" if ground_truth_available else "Proxy Heurístico (Capítulo 17)"

        html_content = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <style>
    :root {{
      --bg: #0f172a;
      --card-bg: #1e293b;
      --border: #334155;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --accent: #38bdf8;
      --accent-green: #22c55e;
      --accent-yellow: #eab308;
      --accent-red: #ef4444;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      height: 100vh;
      overflow: hidden;
    }}
    #sidebar {{
      width: 320px;
      background: var(--card-bg);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      height: 100%;
    }}
    .sidebar-header {{
      padding: 16px;
      border-bottom: 1px solid var(--border);
    }}
    .sidebar-header h2 {{ font-size: 1.1rem; color: var(--accent); }}
    .badge {{
      display: inline-block;
      font-size: 0.75rem;
      padding: 3px 8px;
      border-radius: 999px;
      background: #0369a1;
      color: #e0f2fe;
      margin-top: 6px;
    }}
    .page-list {{
      flex: 1;
      overflow-y: auto;
      padding: 8px;
    }}
    .page-item {{
      padding: 10px 12px;
      border-radius: 6px;
      cursor: pointer;
      margin-bottom: 4px;
      border: 1px solid transparent;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 0.85rem;
    }}
    .page-item:hover {{ background: #334155; }}
    .page-item.active {{ background: #0284c7; border-color: var(--accent); }}
    .conf-tag {{
      font-weight: bold;
      font-size: 0.75rem;
      padding: 2px 6px;
      border-radius: 4px;
    }}
    .conf-high {{ background: #166534; color: #bbf7d0; }}
    .conf-med {{ background: #854d0e; color: #fef08a; }}
    .conf-low {{ background: #991b1b; color: #fecaca; }}
    #content {{
      flex: 1;
      padding: 24px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }}
    .panel {{
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 18px;
    }}
    .panel-title {{
      font-size: 1rem;
      font-weight: 600;
      color: var(--accent);
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    .metrics-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 12px;
    }}
    .metric-card {{
      background: #0f172a;
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 10px;
      text-align: center;
    }}
    .metric-val {{ font-size: 1.25rem; font-weight: bold; margin-top: 4px; }}
    .metric-label {{ font-size: 0.75rem; color: var(--text-muted); }}
    .decomp-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
      margin-top: 10px;
    }}
    .decomp-table th, .decomp-table td {{
      padding: 8px 12px;
      border: 1px solid var(--border);
      text-align: left;
    }}
    .decomp-table th {{ background: #0f172a; color: var(--accent); }}
    .text-preview {{
      font-family: monospace;
      font-size: 0.85rem;
      background: #0f172a;
      padding: 12px;
      border-radius: 6px;
      white-space: pre-wrap;
      max-height: 250px;
      overflow-y: auto;
      border: 1px solid var(--border);
    }}
  </style>
</head>
<body>
  <div id="sidebar">
    <div class="sidebar-header">
      <h2>TupiLingo OCR v5</h2>
      <div class="badge">{metric_badge}</div>
    </div>
    <div class="page-list" id="pageList"></div>
  </div>

  <div id="content">
    <div class="panel">
      <div class="panel-title">
        <span id="pageTitle">Selecione uma página...</span>
        <span id="reviewStatusBadge" class="badge"></span>
      </div>
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-label">{metric_label}</div>
          <div class="metric-val" id="metricFused">-</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">c_ocr (Bruto)</div>
          <div class="metric-val" id="metricOCR">-</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Tempo Real</div>
          <div class="metric-val" id="metricTime">-</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">RAM / VRAM</div>
          <div class="metric-val" id="metricMemory">-</div>
        </div>
      </div>
    </div>

    <div class="panel">
      <div class="panel-title">Decomposição Estrutural da Confiança (Capítulo 9)</div>
      <table class="decomp-table">
        <thead>
          <tr>
            <th>Componente</th>
            <th>Pontuação (0-100)</th>
            <th>Peso</th>
            <th>Impacto no Escore</th>
            <th>Observação Forense</th>
          </tr>
        </thead>
        <tbody id="decompBody"></tbody>
      </table>
    </div>

    <div class="panel">
      <div class="panel-title">Texto Final Transcrito (com Rastreabilidade RAG & Salvaguarda Léxica)</div>
      <div class="text-preview" id="textPreview"></div>
    </div>
  </div>

  <script>
    const pages = {records_json};
    let activeIdx = 0;

    function renderSidebar() {{
      const list = document.getElementById("pageList");
      list.innerHTML = "";
      pages.forEach((p, idx) => {{
        const item = document.createElement("div");
        item.className = "page-item" + (idx === activeIdx ? " active" : "");
        const conf = p.fused_confidence || 0.0;
        let cClass = conf >= 85 ? "conf-high" : (conf >= 60 ? "conf-med" : "conf-low");
        item.innerHTML = `
          <span>${{p.pdf_stem}} p.${{p.page_num}}</span>
          <span class="conf-tag ${{cClass}}">${{conf.toFixed(1)}}%</span>
        `;
        item.onclick = () => selectPage(idx);
        list.appendChild(item);
      }});
    }}

    function selectPage(idx) {{
      activeIdx = idx;
      renderSidebar();
      const p = pages[idx];
      if (!p) return;

      document.getElementById("pageTitle").innerText = `${{p.pdf_stem}} — Página ${{p.page_num}}`;
      
      const rBadge = document.getElementById("reviewStatusBadge");
      if (p.needs_review) {{
        rBadge.innerText = "PENDENTE REVISÃO HUMANA";
        rBadge.style.background = "#b91c1c";
      }} else {{
        rBadge.innerText = "HOMOLOGADO AUTOMÁTICO";
        rBadge.style.background = "#15803d";
      }}

      document.getElementById("metricFused").innerText = (p.fused_confidence || 0.0).toFixed(1) + "%";
      document.getElementById("metricOCR").innerText = (p.ocr_conf || 0.0).toFixed(1) + "%";
      document.getElementById("metricTime").innerText = (p.elapsed_seconds || 0.0).toFixed(2) + "s";
      document.getElementById("metricMemory").innerText = `${{p.rss_mb || 0}}M / ${{p.vram_mb || 0}}M`;

      // Decomposição Table
      const d = p.decomposition || {{}};
      const tbody = document.getElementById("decompBody");
      tbody.innerHTML = `
        <tr><td>c_ocr (Reconhecimento Dual)</td><td>${{(d.ocr_conf || p.ocr_conf || 0).toFixed(1)}}</td><td>0.45</td><td>${{((d.ocr_conf || p.ocr_conf || 0)*0.45).toFixed(1)}}</td><td>RapidOCR GPU + Tesseract LSTM</td></tr>
        <tr><td>c_vis (Qualidade Forense)</td><td>${{(d.visual_conf || 80.0).toFixed(1)}}</td><td>0.15</td><td>${{((d.visual_conf || 80.0)*0.15).toFixed(1)}}</td><td>Contraste RMS e densidade de traço</td></tr>
        <tr><td>c_lex (Conformidade Léxica)</td><td>${{(d.lexical_conf || 0.0).toFixed(1)}}</td><td>0.20</td><td>${{((d.lexical_conf || 0.0)*0.20).toFixed(1)}}</td><td>${{d.floor_trap_triggered ? "Trava de Piso Acionada (Zero correções)" : "Validado no léxico Tupi"}}</td></tr>
        <tr><td>c_rag (Evidência no Corpus)</td><td>${{(d.rag_conf || 0.0).toFixed(1)}}</td><td>0.10</td><td>${{((d.rag_conf || 0.0)*0.10).toFixed(1)}}</td><td>${{d.floor_trap_triggered ? "Trava de Piso Acionada (Zero correções)" : "Citação formal de chunk local"}}</td></tr>
        <tr><td>c_consensus (Votação Ensemble)</td><td>${{(d.consensus_conf || 100.0).toFixed(1)}}</td><td>0.10</td><td>${{((d.consensus_conf || 100.0)*0.10).toFixed(1)}}</td><td>Beam Search Consensus entre motores</td></tr>
      `;

      document.getElementById("textPreview").innerText = p.final_text || "(Nenhum texto extraído)";
    }}

    renderSidebar();
    if (pages.length > 0) selectPage(0);
  </script>
</body>
</html>
"""
        with open(self.output_path, "w", encoding="utf-8") as f:
            f.write(html_content)

        return self.output_path
