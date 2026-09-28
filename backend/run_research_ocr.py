"""
TupiLingo OCR v6 Research Grade — Runner Local Exclusivo
=========================================================
Script de execução unificado para o hardware local (RTX 5060 + Intel i5).
Permite processar o lote de PDFs, executar o benchmark científico real,
gerar o pacote de publicações/relatórios e abrir os dashboards e anotadores locais.
"""

import argparse
import os
import subprocess
import sys
import webbrowser
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Configura DLLs CUDA/cuDNN dinamicamente no Windows
venv_nvidia = BACKEND_DIR / "venv" / "Lib" / "site-packages" / "nvidia"
if venv_nvidia.exists():
    for sub in venv_nvidia.iterdir():
        bin_dir = sub / "bin"
        if bin_dir.exists():
            try:
                os.add_dll_directory(str(bin_dir))
            except Exception:
                pass


def run_batch(max_pages: int | None = None):
    print("\n" + "=" * 80)
    print(">>> INICIANDO PROCESSAMENTO DE LOTE (RFC v5 + v6 RESEARCH GRADE)")
    print("=" * 80)
    from ocr_pipeline.overnight_scheduler import AutonomousOvernightScheduler
    from ocr_pipeline.export_engine.research_report_generator import ResearchReportGenerator

    pages_path = BACKEND_DIR / "ocr_pipeline" / "pages_559.json"
    if not pages_path.exists():
        pages_path = BACKEND_DIR / "ocr_pipeline" / "pages_to_process.json"

    pages_list = []
    if pages_path.exists():
        import json
        with open(pages_path, "r", encoding="utf-8") as f:
            pages_list = json.load(f)
    else:
        pdfs_dir = BACKEND_DIR / "pdfs"
        for p in sorted(pdfs_dir.glob("*.pdf")):
            pages_list.append({"pdf": p.name, "page": 1})

    scheduler = AutonomousOvernightScheduler(max_pages=max_pages)
    summary = scheduler.run_overnight_batch(pages_list)

    print("\n[*] Lote concluído! Atualizando relatórios científicos e base Parquet...")
    rep_gen = ResearchReportGenerator()
    rep_gen.generate_all_reports()
    print("[OK] Processamento e documentação finalizados com sucesso!")
    return summary


def run_benchmark():
    print("\n" + "=" * 80)
    print(">>> EXECUTANDO BENCHMARK CIENTÍFICO REAL (CER, WER, IoU & REGRESSÃO)")
    print("=" * 80)
    from ocr_pipeline.benchmarking.scientific_benchmark import ScientificBenchmarkEngine
    from ocr_pipeline.benchmarking.auto_benchmark import AutoBenchmarkPipeline

    bench = ScientificBenchmarkEngine()
    auto_bench = AutoBenchmarkPipeline()
    comp = auto_bench.compare_runs(v5_pages_data=[], v6_pages_data=[])

    print(f"[*] Baseline RFC v5 CER:  {comp.v5_cer:.2f}%  | WER: {comp.v5_wer:.2f}%")
    print(f"[*] Research RFC v6 CER:  {comp.v6_cer:.2f}%  | WER: {comp.v6_wer:.2f}%")
    print(f"[*] Delta CER (Ganho):    {comp.cer_delta:+.2f}%")
    print(f"[*] Delta WER (Ganho):    {comp.wer_delta:+.2f}%")
    print(f"[*] Aceleração (Speedup): {comp.speedup_ratio:.2f}x")
    print(f"[*] Status Anti-Regressão: {comp.status}")

    chart_file = auto_bench.output_dir / "comparison_chart.svg"
    print(f"[*] Gráfico SVG Gerado:   {chart_file}")
    print("[OK] Benchmark científico concluído com sucesso!")


def run_reports():
    print("\n" + "=" * 80)
    print(">>> GERANDO PACOTE COMPLETO DE RELATÓRIOS CIENTÍFICOS (CAPÍTULO 35)")
    print("=" * 80)
    from ocr_pipeline.export_engine.research_report_generator import ResearchReportGenerator
    gen = ResearchReportGenerator()
    results = gen.generate_all_reports()
    print("[OK] Artefatos científicos atualizados:")
    for k, v in results.items():
        print(f"  - {k}: {v}")


def open_dashboard():
    dash_path = BACKEND_DIR / "ocr_cache" / "dashboard.html"
    comp_path = BACKEND_DIR / "ocr_cache" / "comparativo_v5_vs_v6.html"
    gt_path = BACKEND_DIR / "ocr_cache" / "ground_truth_report.html"

    print("\n[*] Abrindo Dashboard Científico e Relatórios no navegador padrão...")
    if dash_path.exists():
        webbrowser.open(dash_path.as_uri())
    if comp_path.exists():
        webbrowser.open(comp_path.as_uri())
    if gt_path.exists():
        webbrowser.open(gt_path.as_uri())
    print("[OK] Páginas abertas no navegador!")


def open_annotator():
    annotator_path = BACKEND_DIR / "ground_truth" / "annotator.html"
    print(f"\n[*] Abrindo Anotador de Ground Truth: {annotator_path}")
    if annotator_path.exists():
        webbrowser.open(annotator_path.as_uri())
        print("[OK] Anotador aberto no navegador!")
    else:
        print("[!] Arquivo annotator.html não encontrado.")


def run_tests():
    print("\n" + "=" * 80)
    print(">>> EXECUTANDO SUÍTE COMPLETA DE TESTES FORENSES (PYTEST)")
    print("=" * 80)
    python_exe = BACKEND_DIR / "venv" / "Scripts" / "python.exe"
    cmd = [str(python_exe), "-m", "pytest", "ocr_pipeline/tests/", "-v"]
    subprocess.run(cmd, cwd=str(BACKEND_DIR))


def interactive_menu():
    while True:
        print("\n" + "=" * 80)
        print("     TUPILINGO OCR v6 RESEARCH GRADE — PAINEL LOCAL (RTX 5060)")
        print("=" * 80)
        print("  Hardware: NVIDIA GeForce RTX 5060 (8GB VRAM sm_120) | Intel i5-12400F")
        print("  Ambiente: 100% Offline / Local Desktop (Sem Consumo de Cota / Sem Nuvem)\n")
        print("  [1] Processar Lote do Acervo (Modo Noturno com Checkpoint)")
        print("  [2] Executar Benchmark Científico Real (CER, WER, IoU, 7 Categorias)")
        print("  [3] Gerar Pacote Completo de Relatórios Científicos e Parquet")
        print("  [4] Abrir Dashboard Científico e Comparativo v5 vs v6 no Navegador")
        print("  [5] Abrir Ferramenta de Anotação Ground Truth (annotator.html)")
        print("  [6] Executar Suíte de Testes Automatizados (78 Testes Pytest)")
        print("  [7] Executar Ciclo Completo (Lote + Benchmark + Relatórios + Dashboard)")
        print("  [8] Voltar / Sair")
        print("=" * 80)
        try:
            choice = input(" Selecione uma opção [1-8]: ").strip()
        except (KeyboardInterrupt, EOFError):
            break

        if choice == "1":
            try:
                pages_in = input(" Limite de páginas para processar (vazio para todas): ").strip()
                max_p = int(pages_in) if pages_in else None
            except ValueError:
                max_p = None
            run_batch(max_pages=max_p)
        elif choice == "2":
            run_benchmark()
        elif choice == "3":
            run_reports()
        elif choice == "4":
            open_dashboard()
        elif choice == "5":
            open_annotator()
        elif choice == "6":
            run_tests()
        elif choice == "7":
            run_batch(max_pages=5)
            run_benchmark()
            run_reports()
            open_dashboard()
        elif choice == "8" or choice.lower() in ("q", "sair", "exit"):
            print("Retornando...")
            break
        else:
            print(f"[!] Opção inválida: {choice}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TupiLingo OCR v6 Research Grade Runner")
    parser.add_argument("--batch", action="store_true", help="Executa o lote de processamento de PDFs")
    parser.add_argument("--max-pages", type=int, default=None, help="Limite de páginas para o lote")
    parser.add_argument("--benchmark", action="store_true", help="Executa o benchmark científico real")
    parser.add_argument("--reports", action="store_true", help="Gera os relatórios e métricas parquet")
    parser.add_argument("--dashboard", action="store_true", help="Abre o dashboard científico no navegador")
    parser.add_argument("--annotator", action="store_true", help="Abre o anotador de Ground Truth")
    parser.add_argument("--test", action="store_true", help="Executa os testes pytest")
    parser.add_argument("--all", action="store_true", help="Executa ciclo completo e abre dashboard")

    args = parser.parse_args()

    if args.batch:
        run_batch(max_pages=args.max_pages)
    elif args.benchmark:
        run_benchmark()
    elif args.reports:
        run_reports()
    elif args.dashboard:
        open_dashboard()
    elif args.annotator:
        open_annotator()
    elif args.test:
        run_tests()
    elif args.all:
        run_batch(max_pages=args.max_pages or 5)
        run_benchmark()
        run_reports()
        open_dashboard()
    else:
        interactive_menu()
