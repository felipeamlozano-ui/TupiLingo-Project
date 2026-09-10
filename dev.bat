@echo off
setlocal
title TupiLingo - Painel de Inicializacao

set "PROJECT_DIR=%~dp0"

:: Permite passar o numero da opcao direto por linha de comando (ex: dev.bat 2)
if not "%~1"=="" (
    set "CHOICE=%~1"
    goto handle_choice
)

:menu
cls
echo ===============================================================================
echo                            TUPILINGO - STARTUP PANEL
echo ===============================================================================
echo.
echo   Escolha o modo de execucao do ambiente de desenvolvimento / simulacao:
echo.
echo   [1] Completo (Django + Redis + Flutter Debug + PDF Worker + Vocab Worker)
echo       - Ideal para: pipeline RAG continuo e processamento de IA em background.
echo.
echo   [2] Dev Rapido / Economia de Cota (Django + Redis + Flutter Debug) [PADRAO]
echo       - Sem workers! Economiza cotas de IA, CPU e mantem o terminal limpo.
echo.
echo   [3] Simulacao Fidedigna Producao / Staging Mock (Profile / Release) [NOVO]
echo       - Compilacao AOT nativa real, zero overhead JIT/HotReload (120 FPS cravados),
echo         deteccao do IP LAN (0.0.0.0:8000) e injecao dinamica de API_URL.
echo.
echo   [4] Apenas Backend Core (Django + Redis)
echo       - Sobe apenas os servicos de API no Docker (sem Flutter e sem workers).
echo.
echo   [5] Apenas Workers de IA (PDF Worker + Vocab Worker)
echo       - Roda exclusivamente a ingestao e classificacao de dados em background.
echo.
echo   [6] Sair / Cancelar
echo.
echo ===============================================================================

set "CHOICE="
set /p "CHOICE= Selecione uma opcao [1-6]: "

:handle_choice
if "%CHOICE%"=="1" goto opt_full
if "%CHOICE%"=="2" goto opt_fast
if "%CHOICE%"=="3" goto opt_staging_prod
if "%CHOICE%"=="4" goto opt_backend_only
if "%CHOICE%"=="5" goto opt_workers_only
if "%CHOICE%"=="6" goto opt_exit

echo.
echo [!] Opcao invalida: "%CHOICE%"! Digite um numero de 1 a 6.
pause
goto menu

:: -------------------------------------------------------------------------------
:: OPCAO 1: Completo
:: -------------------------------------------------------------------------------
:opt_full
cls
echo ===============================================================================
echo   INICIANDO MODO COMPLETO (DJANGO + FLUTTER DEBUG + TODOS OS WORKERS)
echo ===============================================================================
call :setup_adb
echo [*] Iniciando Docker (Django + Redis + Nginx + PDF Worker + Vocab Worker)...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend (Completo)" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up"
call :wait_django
call :start_flutter_debug
goto end

:: -------------------------------------------------------------------------------
:: OPCAO 2: Dev Rapido (Sem Workers)
:: -------------------------------------------------------------------------------
:opt_fast
cls
echo ===============================================================================
echo   INICIANDO MODO DEV RAPIDO (DJANGO + FLUTTER DEBUG - SEM WORKERS)
echo ===============================================================================
call :setup_adb
echo [*] Iniciando Docker (Apenas Django + Redis - zero consumo de cota de IA)...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend (Dev Rapido)" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up django redis"
call :wait_django
call :start_flutter_debug
goto end

:: -------------------------------------------------------------------------------
:: OPCAO 3: Simulação Fidedigna de Produção / Staging Mock (AOT / Profile / Release)
:: -------------------------------------------------------------------------------
:opt_staging_prod
cls
echo ===============================================================================
echo   MODO SIMULACAO DE PRODUCAO / STAGING MOCK (PERFORMANCE REAL AOT)
echo ===============================================================================

:: 1. Detecção automática de IP LAN
call :detect_ip
echo.
echo [*] IP LAN Detectado para a conexao do Smartphone: %DETECTED_IP%
echo [*] Endpoint da API: http://%DETECTED_IP%:8000
echo.
set "CONFIRM_IP="
set /p "CONFIRM_IP= Pressione ENTER para confirmar ou digite outro IP [%DETECTED_IP%]: "
if not "%CONFIRM_IP%"=="" set "DETECTED_IP=%CONFIRM_IP%"

:: 2. Orquestração de Rede (ADB Reverse + binding)
call :setup_adb

:: 3. Subida e validação do Backend Docker
echo.
echo [*] Verificando e iniciando servicos de suporte (Django + Redis)...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend (Staging 0.0.0.0:8000)" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up django redis"
call :wait_django

:: 4. Menu de modo de compilação AOT Flutter
echo.
echo -------------------------------------------------------------------------------
echo   Selecione o modo de execucao nativa de alta performance:
echo   [1] Profile Mode (flutter run --profile) [RECOMENDADO]
echo       - AOT compilado nativo, medicao de 120 FPS cravados, DevTools GPU ativo.
echo   [2] Release Mode (flutter run --release)
echo       - Compilacao final de usuario, sem VM service, maxima performance.
echo   [3] Build APK Release Fatiado
echo       - Gera APKs otimizados por arquitetura (armeabi-v7a / arm64-v8a).
echo   [4] Build + Install + Server Standalone (Untethered) [NOVO]
echo       - Gera APK, instala automaticamente via ADB e mantem o servidor aberto
echo         para voce testar pelo Wi-Fi sem precisar do cabo USB.
echo -------------------------------------------------------------------------------
set "PROD_MODE=1"
set /p "PROD_MODE= Escolha o modo [1-4] (Padrao: 1): "

cd /d "%PROJECT_DIR%frontend\tupi_lingo"

if "%PROD_MODE%"=="2" goto prod_mode_2
if "%PROD_MODE%"=="3" goto prod_mode_3
if "%PROD_MODE%"=="4" goto prod_mode_4

:: Padrão: Profile Mode (1)
echo.
echo [*] Executando Flutter no modo PROFILE AOT...
echo [*] Injetando API_URL=http://%DETECTED_IP%:8000
call flutter run --profile --dart-define-from-file=.env --dart-define=API_URL=http://%DETECTED_IP%:8000
goto end

:prod_mode_2
echo.
echo [*] Executando Flutter no modo RELEASE AOT...
echo [*] Injetando API_URL=http://%DETECTED_IP%:8000
call flutter run --release --dart-define-from-file=.env --dart-define=API_URL=http://%DETECTED_IP%:8000
goto end

:prod_mode_3
echo.
echo [*] Gerando APK Release otimizado fatiado por ABI...
echo [*] Injetando API_URL=http://%DETECTED_IP%:8000
call flutter build apk --release --split-per-abi --dart-define-from-file=.env --dart-define=API_URL=http://%DETECTED_IP%:8000
echo.
echo [OK] Build concluido! APKs gerados em build\app\outputs\flutter-apk\
pause
goto end

:prod_mode_4
echo.
echo [*] Gerando APK Universal para instalacao direta...
echo [*] Injetando API_URL=http://%DETECTED_IP%:8000
call flutter build apk --release --dart-define-from-file=.env --dart-define=API_URL=http://%DETECTED_IP%:8000
if errorlevel 1 goto build_failed

if not exist "build\app\outputs\flutter-apk\app-release.apk" goto apk_not_found

echo.
echo [*] Instalando APK no dispositivo via ADB...
set "ADB_CMD=adb"
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB_CMD=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

%ADB_CMD% install -r build\app\outputs\flutter-apk\app-release.apk
if errorlevel 1 goto install_failed

echo.
echo [OK] Aplicativo instalado com sucesso no dispositivo!
echo [!] Voce pode desconectar o cabo USB agora caso esteja usando.
echo [!] Abra o TupiLingo no celular e ele conectara via Wi-Fi.
goto server_wait

:build_failed
echo.
echo [ERRO] Falha na compilacao do APK de Release. Verifique os logs acima.
pause
goto end

:apk_not_found
echo.
echo [ERRO] APK nao encontrado em build\app\outputs\flutter-apk\app-release.apk!
echo [!] O processo de build falhou ou foi interrompido.
pause
goto end

:install_failed
echo.
echo [ERRO] Falha ao instalar via ADB. O celular esta conectado e desbloqueado?
pause
goto end

:server_wait
echo.
echo [*] O Servidor Backend continua rodando no IP: http://%DETECTED_IP%:8000
echo [*] Pressione qualquer tecla para encerrar o painel e desligar a rede...
pause >nul
goto end

:: -------------------------------------------------------------------------------
:: OPCAO 4: Apenas Backend Core
:: -------------------------------------------------------------------------------
:opt_backend_only
cls
echo ===============================================================================
echo   INICIANDO APENAS BACKEND CORE (DJANGO + REDIS)
echo ===============================================================================
call :setup_adb
echo [*] Iniciando Docker Django + Redis na porta 8000...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend Core" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up django redis"
call :wait_django
echo.
echo [OK] Backend rodando em http://127.0.0.1:8000/
echo     Pressione qualquer tecla para encerrar este terminal...
pause >nul
goto end

:: -------------------------------------------------------------------------------
:: OPCAO 5: Apenas Workers de IA
:: -------------------------------------------------------------------------------
:opt_workers_only
cls
echo ===============================================================================
echo   INICIANDO APENAS WORKERS DE IA (PDF WORKER + VOCAB WORKER)
echo ===============================================================================
echo [*] Iniciando PDF Worker e Vocab Worker via Docker...
cd /d "%PROJECT_DIR%backend"
start "Docker Workers de IA" cmd /k "docker compose -f docker-compose.yml -f docker-compose.dev.yml up pdf_worker vocab_worker"
echo.
echo [OK] Janela dos Workers iniciada!
echo     Acompanhe o log na janela que foi aberta.
pause
goto end

:: -------------------------------------------------------------------------------
:: OPCAO 6: Sair
:: -------------------------------------------------------------------------------
:opt_exit
echo.
echo Encerrando sem iniciar nenhum servico.
goto end

:: -------------------------------------------------------------------------------
:: FUNCOES AUXILIARES
:: -------------------------------------------------------------------------------
:detect_ip
set "DETECTED_IP=127.0.0.1"
for /f "tokens=*" %%I in ('python -c "import subprocess, re; out = subprocess.check_output('ipconfig', text=True); m = re.findall(r'(?:Wi-Fi|Ethernet)[^\n]*\n(?:[^\n]*\n)*?\s*Endere[^\n]*IPv4[^\n]*:\s*([0-9\.]+)', out, re.I); print(m[0] if m else '')" 2^>nul') do (
    if not "%%I"=="" set "DETECTED_IP=%%I"
)
if "%DETECTED_IP%"=="127.0.0.1" (
    for /f "tokens=*" %%I in ('python -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('8.8.8.8', 80)); print(s.getsockname()[0]); s.close()" 2^>nul') do (
        if not "%%I"=="" set "DETECTED_IP=%%I"
    )
)
exit /b 0

:setup_adb
echo.
echo [1/3] Configurando ADB Reverse na porta 8000...
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
    if errorlevel 1 (
        echo [AVISO] Falha ao configurar ADB Reverse. Prosseguindo...
    ) else (
        echo [OK] ADB Reverse configurado com sucesso!
    )
) else (
    echo [AVISO] adb.exe nao encontrado no caminho padrao do SDK. Prosseguindo...
)
exit /b 0

:wait_django
echo.
echo [2/3] Aguardando Backend Docker responder na porta 8000...
:loop_wait_django
powershell -NoProfile -Command "Start-Sleep -Seconds 3"
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/health/' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }"
if errorlevel 1 (
    echo     ...Django ainda inicializando, aguardando...
    goto loop_wait_django
)
echo [OK] Django esta pronto e respondendo!
exit /b 0

:start_flutter_debug
echo.
echo [3/3] Iniciando o aplicativo Flutter em modo DEBUG...
cd /d "%PROJECT_DIR%frontend\tupi_lingo"
call flutter run --dart-define-from-file=.env
exit /b 0

:end