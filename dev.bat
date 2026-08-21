@echo off
echo ===========================================
echo   Iniciando Ambiente Dev - TupiLingo
echo ===========================================

set "PROJECT_DIR=%~dp0"

:: 1. Executa o túnel USB para contornar o bloqueio do Wi-Fi
echo [1/3] Configurando ADB Reverse na porta 8000...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha ao configurar ADB Reverse. Verifique se o celular esta conectado via USB com Depuracao USB ativada.
    pause
    exit /b 1
)
echo [OK] ADB Reverse configurado com sucesso!

:: 2. Inicia o Django em uma nova janela (usando caminhos absolutos)
echo [2/3] Iniciando o servidor Django...
start "Django Server" cmd /k "cd /d "%PROJECT_DIR%backend" && call venv\Scripts\activate.bat && python manage.py runserver 0.0.0.0:8000"

:: 3. Aguarda o Django ficar pronto antes de iniciar o Flutter
echo [2.5/3] Aguardando Django ficar pronto na porta 8000...
:wait_django
timeout /t 3 /nobreak >nul
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8000/' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }"
if %ERRORLEVEL% NEQ 0 (
    echo     ...Django ainda iniciando, aguardando...
    goto wait_django
)
echo [OK] Django esta respondendo!

:: 4. Inicia o Flutter na janela atual
echo [3/3] Iniciando o aplicativo Flutter...
cd /d "%PROJECT_DIR%frontend\tupi_lingo"
flutter run
