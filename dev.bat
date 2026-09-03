@echo off
echo ===========================================
echo   Iniciando Ambiente Dev - TupiLingo
echo ===========================================

set "PROJECT_DIR=%~dp0"

:: 1. Executa o tunel USB para contornar o bloqueio do Wi-Fi
echo [1/4] Configurando ADB Reverse na porta 8000...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
if %ERRORLEVEL% NEQ 0 (
    echo [AVISO] Falha ao configurar ADB Reverse. Ignorando...
) else (
    echo [OK] ADB Reverse configurado com sucesso!
)


:: 2. Inicia os containers Docker (Django + Nginx + PDF Worker)
echo [2/4] Iniciando o Backend via Docker...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up"

:: 3. Aguarda o Backend ficar pronto antes de iniciar o Flutter
echo [3/4] Aguardando Backend Docker ficar pronto na porta 8000...
:wait_django
timeout /t 4 /nobreak >nul
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/health/' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }"
if %ERRORLEVEL% NEQ 0 (
    echo     ...Django ainda iniciando, aguardando...
    goto wait_django
)
echo [OK] Django esta respondendo!

:: 4. Inicia o Flutter na janela atual
echo [4/4] Iniciando o aplicativo Flutter...
cd /d "%PROJECT_DIR%frontend\tupi_lingo"
flutter run --dart-define-from-file=.env
