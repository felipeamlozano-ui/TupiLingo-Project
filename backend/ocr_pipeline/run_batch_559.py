"""
Executor do Lote Completo de 559 Páginas Reais — Fase 1 (OCR)
TupiLingo OCR Pipeline: XY-Cut + Sauvola + Correção Léxica Tupi + RapidOCR/Tesseract Dual Engine

Recursos de Resiliência:
  - Checkpoint atômico e idempotente via JSONL (batch_559_progress.jsonl).
  - Coleta forçada de lixo (gc.collect()) a cada página para garantir zero vazamento de RAM.
  - Telemetria de memória física (RAM do sistema e RSS do processo) via ctypes Windows API.
  - Rastreamento completo de confiança antes (banco de dados) vs depois (grafo composto).
  - Preservação estrita de caixa original e salvaguarda do léxico Tupi.
"""
import ctypes
import gc
import json
import os
import sqlite3
import sys
import time
from pathlib import Path
from typing import Any

import pypdfium2 as pdfium

# Adiciona diretório raiz do backend ao sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from ocr_pipeline.models import PageType
from ocr_pipeline.pipeline_orchestrator import PipelineOrchestrator

PDFS_DIR = BACKEND_DIR / "pdfs"
DB_PATH = BACKEND_DIR / "vector_store.db"
TUPI_WORDS_FILE = BACKEND_DIR / "tupi_user_words.txt"
LEXICON_DATA_FILE = BACKEND_DIR / "pedagogico" / "lexicon_data.py"
PAGES_JSON = BACKEND_DIR / "ocr_pipeline" / "pages_559.json"
PROGRESS_JSONL = BACKEND_DIR / "ocr_pipeline" / "batch_559_progress.jsonl"
REPRESENTATIVE_CASES_JSON = BACKEND_DIR / "ocr_pipeline" / "representative_cases.json"
SUMMARY_REPORT_JSON = BACKEND_DIR / "ocr_pipeline" / "batch_559_summary.json"

# Estrutura ctypes para ler RAM física do sistema sem dependências extras
class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]

# Garantir codificação UTF-8 no stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Estrutura ctypes para ler Working Set (RSS) do processo atual
class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_uint32),
        ("PageFaultCount", ctypes.c_uint32),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]

def get_memory_telemetry() -> dict[str, float]:
    """Retorna medição instantânea de RAM livre do sistema e RSS do processo em MB."""
    mem = MEMORYSTATUSEX()
    mem.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem))
    
    avail_mb = round(mem.ullAvailPhys / (1024 * 1024), 1)
    total_mb = round(mem.ullTotalPhys / (1024 * 1024), 1)
    load_pct = mem.dwMemoryLoad
    
    # Process Working Set via OpenProcess
    rss_mb = 0.0
    try:
        PROCESS_QUERY_INFORMATION = 0x0400
        PROCESS_VM_READ = 0x0010
        h_proc = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, os.getpid())
        if h_proc:
            pmc = PROCESS_MEMORY_COUNTERS()
            pmc.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
            if ctypes.windll.psapi.GetProcessMemoryInfo(h_proc, ctypes.byref(pmc), ctypes.sizeof(pmc)):
                rss_mb = round(pmc.WorkingSetSize / (1024 * 1024), 1)
            ctypes.windll.kernel32.CloseHandle(h_proc)
    except Exception:
        pass
    
    return {
        "system_avail_mb": avail_mb,
        "system_total_mb": total_mb,
        "system_load_pct": load_pct,
        "process_rss_mb": rss_mb
    }

def load_historical_db_index() -> dict[tuple[str, int], dict[str, Any]]:
    """Carrega índice dos documentos históricos do vector_store.db para recuperação rápida."""
    print("Carregando baseline histórico do banco de dados (vector_store.db)...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT document, metadata, confianca, precisa_revisao FROM documents")
    rows = cursor.fetchall()
    conn.close()

    db_index = {}
    for doc, meta_str, conf, rev in rows:
        try:
            meta = json.loads(meta_str)
            fname = meta.get("file_name") or meta.get("filename") or meta.get("pdf_name")
            page = meta.get("page")
            if fname and page is not None:
                key = (fname, int(page))
                if key not in db_index:
                    db_index[key] = {"chunks": [], "confs": [], "rev": False}
                db_index[key]["chunks"].append(doc)
                if conf is not None:
                    db_index[key]["confs"].append(float(conf))
                if rev == 1:
                    db_index[key]["rev"] = True
        except Exception:
            continue
    print(f"Índice histórico carregado: {len(db_index)} páginas mapeadas.")
    return db_index

def find_historical_data(db_index: dict[tuple[str, int], dict[str, Any]], pdf: str, page: int) -> dict[str, Any]:
    """Busca os dados históricos com tolerância a codificação de nome de arquivo."""
    if (pdf, page) in db_index:
        entry = db_index[(pdf, page)]
        text = "\n".join(entry["chunks"])
        avg_c = float(sum(entry["confs"]) / len(entry["confs"])) if entry["confs"] else None
        return {"text": text, "conf": avg_c, "rev": entry["rev"]}
    
    # Busca por correspondência aproximada de nome de PDF
    for (k_pdf, k_page), entry in db_index.items():
        if k_page == page and (k_pdf in pdf or pdf in k_pdf):
            text = "\n".join(entry["chunks"])
            avg_c = float(sum(entry["confs"]) / len(entry["confs"])) if entry["confs"] else None
            return {"text": text, "conf": avg_c, "rev": entry["rev"]}
            
    return {"text": "", "conf": None, "rev": False}

def load_completed_page_keys() -> set:
    """Carrega chaves de páginas já processadas do arquivo JSONL de progresso."""
    completed = set()
    if PROGRESS_JSONL.exists():
        with open(PROGRESS_JSONL, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    completed.add(f"{data['pdf']}::{data['page']}")
                except Exception:
                    continue
    return completed

def run_batch():
    t_global_start = time.time()
    iso_start = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t_global_start))
    
    print("=" * 80)
    print("INICIANDO EXECUÇÃO EM LOTE — FASE 1 (559 PÁGINAS)")
    print(f"Timestamp Início: {iso_start}")
    print("=" * 80)
    
    initial_mem = get_memory_telemetry()
    print(f"Telemetria Inicial de Memória: RAM Livre = {initial_mem['system_avail_mb']} MB, "
          f"Carga = {initial_mem['system_load_pct']}%, RSS Processo = {initial_mem['process_rss_mb']} MB")
    
    with open(PAGES_JSON, "r", encoding="utf-8") as f:
        target_pages = json.load(f)
    print(f"Total de páginas no escopo: {len(target_pages)}")
    
    db_index = load_historical_db_index()
    completed_keys = load_completed_page_keys()
    print(f"Páginas já concluídas em checkpoints anteriores: {len(completed_keys)}")
    
    # Inicializar orquestrador do pipeline
    print("Instanciando PipelineOrchestrator com Tesseract + RapidOCR (threads limitadas a 6)...")
    orchestrator = PipelineOrchestrator(
        tupi_words_path=TUPI_WORDS_FILE,
        lexicon_data_path=LEXICON_DATA_FILE,
        cpu_threads=6
    )
    
    current_pdf_name = None
    current_pdf_doc = None
    
    # Candidatos a casos representativos
    rep_easy = None
    rep_med = None
    rep_worst = None
    
    # Abrir arquivo de progresso em modo append
    progress_file = open(PROGRESS_JSONL, "a", encoding="utf-8")
    
    processed_in_this_run = 0
    total_pages_count = len(target_pages)
    
    try:
        for idx, item in enumerate(target_pages, 1):
            pdf_fname = item["pdf"]
            p_num = item["page"]
            page_key = f"{pdf_fname}::{p_num}"
            
            if page_key in completed_keys:
                continue
                
            t_page_start = time.time()
            
            # Carregar documento PDF apenas quando muda o arquivo
            if current_pdf_name != pdf_fname:
                if current_pdf_doc is not None:
                    del current_pdf_doc
                    gc.collect()
                pdf_path = PDFS_DIR / pdf_fname
                if not pdf_path.exists():
                    print(f"ERRO: Arquivo não encontrado: {pdf_fname}")
                    continue
                current_pdf_doc = pdfium.PdfDocument(str(pdf_path))
                current_pdf_name = pdf_fname
                
            page_idx = p_num - 1
            if page_idx < 0 or page_idx >= len(current_pdf_doc):
                print(f"ERRO: Página fora dos limites: {pdf_fname} pág {p_num}")
                continue
                
            page = current_pdf_doc[page_idx]
            # Render a 300 DPI (escala 300 / 72 = 4.1666)
            pil_img = page.render(scale=300.0 / 72.0).to_pil()
            
            # Recuperar baseline histórico
            hist_data = find_historical_data(db_index, pdf_fname, p_num)
            hist_conf = item.get("historical_score") or hist_data["conf"]
            hist_rev = item.get("precisa_revisao") or hist_data["rev"]
            hist_text = hist_data["text"]
            
            # Execução forçada da Fase 1 no lote dos 559 alvos
            profile, ocr_res, chunks, audit = orchestrator.process_page(
                pil_img=pil_img,
                filename=pdf_fname,
                page_num=p_num,
                historical_ocr_conf=hist_conf,
                precisa_revisao_hist=hist_rev,
                page_type=PageType.SCAN,
                force_phase1=True
            )
            
            elapsed_page = time.time() - t_page_start
            mem_now = get_memory_telemetry()
            
            record = {
                "pdf": pdf_fname,
                "page": p_num,
                "dimensions": f"{profile.width}x{profile.height}",
                "columns_detected": profile.num_columns,
                "has_bleed_through": profile.has_bleed_through,
                "blur_laplacian": round(profile.blur_laplacian, 1),
                "contrast_rms": round(profile.contrast_rms, 1),
                "skew_angle": round(profile.skew_angle, 2),
                "quality_score_fase0": profile.quality_score,
                "routing_decision": profile.routing_decision.value,
                "confidence_before": round(hist_conf, 2) if hist_conf is not None else None,
                "confidence_after": round(audit.confidence_after, 2),
                "delta_confidence": round(audit.confidence_after - (hist_conf or 0.0), 2) if hist_conf is not None else None,
                "engine_used": audit.engine_used,
                "agreement_rate": round(audit.agreement_rate, 4),
                "lexical_corrections_count": audit.lexical_corrections_count,
                "sample_corrections": ocr_res.corrections_applied[:5] if ocr_res else [],
                "chunks_generated": len(chunks),
                "dictionary_entries_found": audit.dictionary_entries_found,
                "needs_review": audit.needs_manual_review,
                "sanity_status": audit.sanity_status,
                "elapsed_seconds": round(elapsed_page, 2),
                "char_count_before": len(hist_text),
                "char_count_after": len(ocr_res.text_cleaned) if ocr_res else 0,
                "system_avail_mb": mem_now["system_avail_mb"],
                "process_rss_mb": mem_now["process_rss_mb"],
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
            }
            
            # Gravação atômica no JSONL
            progress_file.write(json.dumps(record, ensure_ascii=False) + "\n")
            progress_file.flush()
            
            completed_keys.add(page_key)
            processed_in_this_run += 1
            
            # Rastreamento de casos representativos
            if hist_conf is not None:
                # Caso Fácil: histórico >= 85 e boa melhora
                if rep_easy is None and hist_conf >= 85.0 and audit.confidence_after >= 90.0:
                    rep_easy = {
                        "category": "facil",
                        "pdf": pdf_fname,
                        "page": p_num,
                        "conf_before": hist_conf,
                        "conf_after": audit.confidence_after,
                        "text_before": hist_text[:1200],
                        "text_after": ocr_res.text_cleaned[:1200] if ocr_res else "",
                        "corrections": ocr_res.corrections_applied if ocr_res else []
                    }
                # Caso Mediano: histórico entre 60 e 80
                elif rep_med is None and 60.0 <= hist_conf <= 80.0 and audit.confidence_after >= 80.0:
                    rep_med = {
                        "category": "mediana",
                        "pdf": pdf_fname,
                        "page": p_num,
                        "conf_before": hist_conf,
                        "conf_after": audit.confidence_after,
                        "text_before": hist_text[:1200],
                        "text_after": ocr_res.text_cleaned[:1200] if ocr_res else "",
                        "corrections": ocr_res.corrections_applied if ocr_res else []
                    }
                # Pior Caso: histórico <= 45
                elif rep_worst is None and hist_conf <= 45.0:
                    rep_worst = {
                        "category": "pior_caso",
                        "pdf": pdf_fname,
                        "page": p_num,
                        "conf_before": hist_conf,
                        "conf_after": audit.confidence_after,
                        "text_before": hist_text[:1200],
                        "text_after": ocr_res.text_cleaned[:1200] if ocr_res else "",
                        "corrections": ocr_res.corrections_applied if ocr_res else []
                    }
            
            # Log de progresso a cada página
            total_done = len(completed_keys)
            pct = (total_done / total_pages_count) * 100.0
            print(f"[{total_done:3d}/{total_pages_count:3d} - {pct:5.1f}%] {pdf_fname[:28]:<28} pág {p_num:3d} | "
                  f"Conf: {hist_conf or 0.0:5.1f} -> {audit.confidence_after:5.1f} (Delta {record['delta_confidence'] or 0.0:+5.1f}) | "
                  f"Chunks: {len(chunks):2d} | Tempo: {elapsed_page:5.2f}s | RAM Livre: {mem_now['system_avail_mb']:5.0f}MB | RSS: {mem_now['process_rss_mb']:5.0f}MB", flush=True)
            
            # Limpeza forçada de buffers de imagem
            del pil_img
            if ocr_res:
                del ocr_res
            del chunks
            del profile
            del audit
            gc.collect()
            
    except KeyboardInterrupt:
        print("\n[INTERRUPÇÃO MANUAL DETECTADA] Salvando checkpoint de progresso...")
    except Exception as e:
        print(f"\n[FALHA NA EXECUÇÃO] Exceção capturada: {e!s}")
        import traceback
        traceback.print_exc()
    finally:
        progress_file.close()
        if current_pdf_doc is not None:
            del current_pdf_doc
            gc.collect()
            
        t_global_end = time.time()
        total_elapsed = t_global_end - t_global_start
        iso_end = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t_global_end))
        final_mem = get_memory_telemetry()
        
        print("\n" + "=" * 80)
        print("FINAL DA EXECUÇÃO DO LOTE")
        print(f"Timestamp Fim: {iso_end}")
        print(f"Tempo Total Decorrido: {total_elapsed:.2f}s ({total_elapsed / 60.0:.2f} minutos)")
        print(f"Páginas Processadas nesta rodada: {processed_in_this_run}")
        print(f"Total Concluído Acumulado: {len(completed_keys)} de {total_pages_count}")
        print(f"Telemetria Final de Memória: RAM Livre = {final_mem['system_avail_mb']} MB, RSS = {final_mem['process_rss_mb']} MB")
        print("=" * 80)
        
        # Salva casos representativos
        if rep_easy or rep_med or rep_worst:
            reps = {"easy": rep_easy, "medium": rep_med, "worst": rep_worst}
            with open(REPRESENTATIVE_CASES_JSON, "w", encoding="utf-8") as f:
                json.dump(reps, f, indent=2, ensure_ascii=False)
            print(f"Casos representativos salvos em: {REPRESENTATIVE_CASES_JSON}")

if __name__ == "__main__":
    run_batch()
