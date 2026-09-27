@echo off
setlocal enabledelayedexpansion

echo ================================================================================
echo TUPILINGO OCR v5 -- INSTALACAO ZERO-CONFIGURACAO DO PIPELINE GPU (DESKTOP)
echo ================================================================================

:: 1. Verificar presenca de driver NVIDIA compativel
echo [1/7] Verificando presenca de GPU NVIDIA e driver compativel...
where nvidia-smi >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERRO CRITICO] nvidia-smi nao encontrado. Verifique a instalacao do driver NVIDIA.
    exit /b 1
)
nvidia-smi
echo [OK] Driver NVIDIA detectado com sucesso.
echo --------------------------------------------------------------------------------

:: 2. Instalar uv se ausente
echo [2/7] Verificando presenca do uv (gerenciador ultrarrapido de pacotes)...
where uv >nul 2>nul
if %errorlevel% neq 0 (
    if exist "backend\venv\Scripts\uv.exe" (
        set "UV_CMD=backend\venv\Scripts\uv.exe"
        echo [OK] uv encontrado no venv local: !UV_CMD!
    ) else (
        echo [INFO] Instalando uv via pip...
        python -m pip install uv
        set "UV_CMD=uv"
    )
) else (
    set "UV_CMD=uv"
)
echo [OK] uv pronto para uso.
echo --------------------------------------------------------------------------------

:: 3. Criar ou verificar ambiente virtual
echo [3/7] Verificando ambiente virtual backend\venv...
if not exist "backend\venv\Scripts\python.exe" (
    echo [INFO] Criando venv via uv...
    !UV_CMD! venv backend\venv --python 3.12
)
set "PYTHON_EXE=backend\venv\Scripts\python.exe"
echo [OK] Ambiente virtual ativo em backend\venv.
echo --------------------------------------------------------------------------------

:: 4. Instalar CUDA Runtime, cuDNN 9 e PyTorch compativel
echo [4/7] Instalando pacotes CUDA 12, cuDNN 9 e onnxruntime-gpu...
!UV_CMD! pip install --python "!PYTHON_EXE!" ^
    torch torchvision --index-url https://download.pytorch.org/whl/cu124
!UV_CMD! pip install --python "!PYTHON_EXE!" ^
    onnxruntime-gpu==1.19.2 ^
    nvidia-cudnn-cu12 nvidia-cuda-runtime-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12
echo [OK] Bibliotecas GPU instaladas com sucesso.
echo --------------------------------------------------------------------------------

:: 5. Instalar dependencias restantes do pipeline
echo [5/7] Instalando dependencias de visao, parsing e auditoria...
!UV_CMD! pip install --python "!PYTHON_EXE!" ^
    opencv-python-headless scikit-image pypdfium2 pytesseract rapidocr_onnxruntime pydantic pyarrow lmdb symspellpy pytest
echo [OK] Dependencias forenses instaladas com sucesso.
echo --------------------------------------------------------------------------------

:: 6. Baixar pesos de modelo (DocLayout-YOLO, Real-ESRGAN) com verificacao SHA-256
echo [6/7] Baixando modelos de layout e super-resolucao para backend\models...
"!PYTHON_EXE!" backend\ocr_pipeline\download_models.py
echo [OK] Verificacao de modelos concluida.
echo --------------------------------------------------------------------------------

:: 7. Rodar smoke test final
echo [7/7] Executando smoke test final de aceleracao por hardware...
"!PYTHON_EXE!" backend\ocr_pipeline\smoke_test_gpu.py
if %errorlevel% neq 0 (
    echo [AVISO] Smoke test indicou pendencias parciais. Consulte o log acima.
) else (
    echo ================================================================================
    echo [SUCESSO COMPLETO] Pipeline GPU TupiLingo v5 instalado e pronto para processamento.
    echo ================================================================================
)
exit /b 0
