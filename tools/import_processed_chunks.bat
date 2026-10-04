@echo off
setlocal enabledelayedexpansion

echo ================================================================================
echo TUPILINGO OCR v5 -- IMPORTADOR DE ARTIFACT BUNDLE (NOTEBOOK / VOCAB_WORKER)
echo ================================================================================

set "BASE_DIR=%~dp0"
set "BACKEND_DIR=%BASE_DIR%backend"

if exist "backend\venv\Scripts\python.exe" (
    set "PYTHON_EXE=backend\venv\Scripts\python.exe"
) else (
    set "PYTHON_EXE=python"
)

echo [INFO] Procurando Artifact Bundle mais recente baixado do Google Drive...
echo [INFO] Ambiente Notebook: Consumo exclusivo de Parquet/JSONL. Sem OCR, sem GPU.
echo --------------------------------------------------------------------------------

"!PYTHON_EXE!" "%BACKEND_DIR%\ocr_pipeline\import_bundle_notebook.py" %*

if %errorlevel% equ 0 (
    echo --------------------------------------------------------------------------------
    echo [SUCESSO] Chunks importados e validados no Notebook para o vocab_worker.
    echo ================================================================================
) else (
    echo --------------------------------------------------------------------------------
    echo [ERRO] Falha na importacao do bundle. Verifique se o arquivo esta corrompido.
    echo ================================================================================
)
exit /b %errorlevel%
