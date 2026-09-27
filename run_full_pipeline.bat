@echo off
setlocal enabledelayedexpansion

echo ================================================================================
echo TUPILINGO OCR v5 -- ORQUESTRADOR COMPLETO DE PIPELINE FORENSE GPU (DESKTOP)
echo ================================================================================

if not exist "backend\venv\Scripts\python.exe" (
    echo [ERRO] Ambiente virtual nao encontrado. Execute install_gpu_pipeline.bat primeiro.
    exit /b 1
)

set "PYTHON_EXE=backend\venv\Scripts\python.exe"
set "BASE_DIR=%~dp0"
set "BACKEND_DIR=%BASE_DIR%backend"

:: Garantir que os PDFs existam
if not exist "%BACKEND_DIR%\pdfs" (
    echo [ERRO] Pasta de PDFs nao encontrada em %BACKEND_DIR%\pdfs.
    exit /b 1
)

echo [INFO] Iniciando pipeline forense com aceleracao GPU (RTX 5060)...
echo [INFO] Orquestrando: Diagnostico - Preprocessamento - Layout - Super-Resolucao - OCR - Votacao - Confianca - Rollback - Exportacao do Artifact Bundle.
echo --------------------------------------------------------------------------------

"!PYTHON_EXE!" "%BACKEND_DIR%\ocr_pipeline\overnight_scheduler.py" %*

if %errorlevel% equ 0 (
    echo --------------------------------------------------------------------------------
    echo [SUCESSO] Lote processado com sucesso. Artifact Bundle gerado para transporte.
    echo ================================================================================
) else (
    echo --------------------------------------------------------------------------------
    echo [FALHA / INTERRUPCAO] O lote foi pausado ou falhou. O progresso foi salvo em checkpoint.
    echo ================================================================================
)
exit /b %errorlevel%
