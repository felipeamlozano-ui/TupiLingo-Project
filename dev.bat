@echo off
setlocal EnableDelayedExpansion
title TupiLingo - Painel de Inicializacao

set "PROJECT_DIR=%~dp0"

:: Permite passar o numero da opcao direto por linha de comando (ex: dev.bat 2)
if not "%~1"=="" (
    set "CHOICE=%~1"
    goto handle_choice
)

:menu
set "CHOICE="
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
echo   [3] Modo Producao Real (Backend Local + Tunel Cloudflare + Build APK)
echo       - Backend de Producao (Gunicorn WSGI + Redis + Supabase, DEBUG=False),
echo         Tunel reverso Cloudflare (trycloudflare.com) e geracao de APK Release.
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
if "%CHOICE%"=="3" goto opt_prod_tunnel
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
:: OPCAO 3: Modo Producao Real (Backend Local + Tunel Cloudflare + Build APK)
:: -------------------------------------------------------------------------------
:opt_prod_tunnel
cls
echo ===============================================================================
echo   MODO PRODUCAO REAL (BACKEND LOCAL + TUNEL CLOUDFLARE + BUILD APK EXTERNO)
echo ===============================================================================
echo.
echo   Selecione a operacao desejada:
echo.
echo   [1] Subir Producao + Tunel + Build APK de Release
echo       - Garante o cloudflared, sobe o tunel, para o Docker temporariamente
echo         (protecao de RAM 7.3GB), compila o APK com a URL Cloudflare injetada
echo         e reinicia o backend no Docker em modo de producao.
echo.
echo   [2] Subir Apenas Backend + Tunel
echo       - Sobe o Docker de producao (Gunicorn + Redis) e o Cloudflare Tunnel
echo         (para manter o servidor aberto para quem ja tem o APK instalado).
echo.
echo   [3] Voltar ao Menu Principal
echo.
echo ===============================================================================
set "SUB3_CHOICE="
set /p "SUB3_CHOICE= Selecione uma sub-opcao [1-3]: "

if "%SUB3_CHOICE%"=="1" goto opt_prod_build_and_serve
if "%SUB3_CHOICE%"=="2" goto opt_prod_serve_only
if "%SUB3_CHOICE%"=="3" goto menu

echo.
echo [!] Opcao invalida: "%SUB3_CHOICE%"! Digite 1, 2 ou 3.
pause
goto opt_prod_tunnel

:: -------------------------------------------------------------------------------
:: SUB-OPCAO 1: Subir Producao + Tunel + Build APK de Release
:: -------------------------------------------------------------------------------
:opt_prod_build_and_serve
echo.
echo ===============================================================================
echo   ETAPA 1/4: Verificando Cloudflare Tunnel e Obtendo URL Publica
echo ===============================================================================
call :ensure_cloudflared
if errorlevel 1 goto end

call :resolve_cloudflare_url
if errorlevel 1 goto end

echo.
echo ===============================================================================
echo   ETAPA 2/4: Liberando Memoria RAM para Compilacao Gradle
echo ===============================================================================
echo [*] Parando conteineres Docker para evitar estouro de RAM (limite da maquina: 7.3GB)...
echo [!] O Gradle Daemon e a compilacao AOT do Flutter consomem ate 2.5GB de RAM.
cd /d "%PROJECT_DIR%backend"
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml stop 2>nul
docker compose -f docker-compose.yml -f docker-compose.dev.yml stop 2>nul
echo [OK] Conteineres parados. Memoria RAM liberada para o Gradle.

echo.
echo ===============================================================================
echo   ETAPA 3/4: Compilando APK de Release (Flutter AOT)
echo ===============================================================================
echo [*] Compilando APK Release com API_URL=%CLOUDFLARE_URL%...
cd /d "%PROJECT_DIR%frontend\tupi_lingo"
call flutter build apk --release --dart-define-from-file=.env --dart-define=API_URL=%CLOUDFLARE_URL%
if errorlevel 1 goto build_failed
if not exist "build\app\outputs\flutter-apk\app-release.apk" goto apk_not_found

echo.
echo [OK] APK de Release compilado com sucesso!
echo     Localizacao: frontend\tupi_lingo\build\app\outputs\flutter-apk\app-release.apk

echo.
echo ===============================================================================
echo   ETAPA 4/4: Reiniciando Backend Docker de Producao (Gunicorn + Redis)
echo ===============================================================================
echo [*] Iniciando servicos de backend em modo Producao Real (DEBUG=False)...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend (Producao Gunicorn)" cmd /k "docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up django redis"
set "WAIT_TARGET_IP=127.0.0.1"
call :wait_django
goto prod_success_summary

:: -------------------------------------------------------------------------------
:: SUB-OPCAO 2: Subir Apenas Backend + Tunel
:: -------------------------------------------------------------------------------
:opt_prod_serve_only
echo.
echo ===============================================================================
echo   ETAPA 1/2: Iniciando Backend Docker de Producao (Gunicorn + Redis)
echo ===============================================================================
call :ensure_cloudflared
if errorlevel 1 goto end

echo [*] Iniciando servicos de backend em modo Producao Real (DEBUG=False)...
cd /d "%PROJECT_DIR%backend"
start "Docker Backend (Producao Gunicorn)" cmd /k "docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up django redis"
set "WAIT_TARGET_IP=127.0.0.1"
call :wait_django

echo.
echo ===============================================================================
echo   ETAPA 2/2: Inicializando Cloudflare Quick Tunnel
echo ===============================================================================
call :start_cloudflare

:: Carrega CLOUDFLARE_URL do .env se existir apenas para exibicao
if not defined CLOUDFLARE_URL (
    if exist "%PROJECT_DIR%backend\.env" (
        for /f "usebackq tokens=1,* delims==" %%A in ("%PROJECT_DIR%backend\.env") do (
            if /i "%%A"=="CLOUDFLARE_URL" set "CLOUDFLARE_URL=%%B"
        )
    )
)
goto prod_success_summary

:prod_success_summary
cls
echo ===============================================================================
echo              TUPILINGO - AMBIENTE DE PRODUCAO ATIVO E OPERACIONAL
echo ===============================================================================
echo.
echo   [OK] Servidor Backend:   Gunicorn WSGI (2 Workers, DEBUG=False, Porta 8000)
echo   [OK] Cache / Filas:      Redis (Porta 6379)
echo   [OK] Banco de Dados:     PostgreSQL (Supabase Cloud Pooler)
echo   [OK] Endpoint Local:     http://127.0.0.1:8000/
if defined CLOUDFLARE_URL (
echo   [OK] Endpoint Publico:   %CLOUDFLARE_URL%
) else (
echo   [OK] Endpoint Publico:   Consulte a URL na janela do Cloudflare Tunnel
)
if exist "%PROJECT_DIR%frontend\tupi_lingo\build\app\outputs\flutter-apk\app-release.apk" (
echo   [OK] APK de Release:     frontend\tupi_lingo\build\app\outputs\flutter-apk\app-release.apk
)
echo.
echo -------------------------------------------------------------------------------
echo   INSTRUCOES PARA TESTES EXTERNOS:
echo   - Dispositivos em 4G/5G ou Wi-Fi externo ja podem conectar na URL do Cloudflare.
echo   - O tunel permanecera 100%% online e ilimitado enquanto a janela estiver aberta.
echo   - Pressione qualquer tecla para encerrar o servidor e desligar o backend.
echo -------------------------------------------------------------------------------
pause >nul
echo.
echo [*] Encerrando servicos de producao no Docker...
cd /d "%PROJECT_DIR%backend"
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml stop django redis 2>nul
echo [OK] Servicos encerrados com sucesso.
goto end

:build_failed
echo.
echo [ERRO] Falha na compilacao do APK de Release. Verifique os logs do Flutter acima.
pause
goto end

:apk_not_found
echo.
echo [ERRO] APK nao encontrado em build\app\outputs\flutter-apk\app-release.apk!
echo [!] O processo de build foi interrompido antes de finalizar o arquivo.
pause
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
:: FUNCOES AUXILIARES DO CLOUDFLARE TUNNEL
:: -------------------------------------------------------------------------------

:: -------------------------------------------------------------------------------
:: :detect_cloudflared -- Localiza o binario cloudflared.exe
:: -------------------------------------------------------------------------------
:detect_cloudflared
set "CLOUDFLARED_BIN="
if exist "%PROJECT_DIR%tools\cloudflared.exe" (
    set "CLOUDFLARED_BIN=%PROJECT_DIR%tools\cloudflared.exe"
    exit /b 0
)
if exist "%PROJECT_DIR%cloudflared.exe" (
    set "CLOUDFLARED_BIN=%PROJECT_DIR%cloudflared.exe"
    exit /b 0
)
where cloudflared.exe >nul 2>&1
if %errorlevel% equ 0 (
    set "CLOUDFLARED_BIN=cloudflared.exe"
    exit /b 0
)
exit /b 1

:: -------------------------------------------------------------------------------
:: :ensure_cloudflared -- Garante que o cloudflared.exe existe ou realiza o download
:: -------------------------------------------------------------------------------
:ensure_cloudflared
call :detect_cloudflared
if defined CLOUDFLARED_BIN exit /b 0

echo.
echo ===============================================================================
echo   CLOUDFLARED NAO ENCONTRADO - DOWNLOAD AUTOMATICO
echo ===============================================================================
echo [*] Baixando executavel oficial do Cloudflare Tunnel via GitHub Releases...
echo [*] Destino: tools\cloudflared.exe
if not exist "%PROJECT_DIR%tools" mkdir "%PROJECT_DIR%tools"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Write-Host 'Baixando cloudflared-windows-amd64.exe...'; (New-Object System.Net.WebClient).DownloadFile('https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe', '%PROJECT_DIR%tools\cloudflared.exe'); Write-Host 'Download concluido com sucesso!' -ForegroundColor Green"

if not exist "%PROJECT_DIR%tools\cloudflared.exe" (
    echo.
    echo [ERRO] Falha ao baixar o cloudflared.exe automaticamente.
    echo [!] Verifique sua conexao com a internet ou baixe manualmente de:
    echo     https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
    echo     e salve em: %PROJECT_DIR%tools\cloudflared.exe
    pause
    exit /b 1
)

set "CLOUDFLARED_BIN=%PROJECT_DIR%tools\cloudflared.exe"
echo [OK] cloudflared.exe pronto para uso: !CLOUDFLARED_BIN!
exit /b 0

:: -------------------------------------------------------------------------------
:: :start_cloudflare -- Inicia o tunel reverso do Cloudflare em janela dedicada
:: -------------------------------------------------------------------------------
:start_cloudflare
call :detect_cloudflared
if not defined CLOUDFLARED_BIN (
    call :ensure_cloudflared
    if errorlevel 1 exit /b 1
)

tasklist /fi "imagename eq cloudflared.exe" 2>nul | findstr /i "cloudflared.exe" >nul
if %errorlevel% equ 0 (
    echo [*] Cloudflare Tunnel ja esta em execucao em janela dedicada.
    exit /b 0
)

echo [*] Disparando Cloudflare Quick Tunnel na porta 8000...
if exist "%PROJECT_DIR%tools\cloudflared.log" del /f /q "%PROJECT_DIR%tools\cloudflared.log" 2>nul
start "Cloudflare Tunnel" cmd /k ""%CLOUDFLARED_BIN%" tunnel --url http://127.0.0.1:8000 --logfile "%PROJECT_DIR%tools\cloudflared.log""
exit /b 0

:: -------------------------------------------------------------------------------
:: :resolve_cloudflare_url -- Obtem ou confirma a URL publica HTTPS do Cloudflare
:: -------------------------------------------------------------------------------
:resolve_cloudflare_url
:: 1. Tenta carregar CLOUDFLARE_URL do backend\.env se existir
if not defined CLOUDFLARE_URL (
    if exist "%PROJECT_DIR%backend\.env" (
        for /f "usebackq tokens=1,* delims==" %%A in ("%PROJECT_DIR%backend\.env") do (
            if /i "%%A"=="CLOUDFLARE_URL" (
                set "CANDIDATE_URL=%%B"
                if not "!CANDIDATE_URL!"=="" if not "!CANDIDATE_URL!"=="https://xxxx.trycloudflare.com" (
                    set "CLOUDFLARE_URL=!CANDIDATE_URL!"
                )
            )
        )
    )
)

:: 2. Se ja temos uma URL configurada no .env, pergunta se deseja reutilizar
if defined CLOUDFLARE_URL (
    echo.
    echo [*] URL do Cloudflare encontrada no .env: !CLOUDFLARE_URL!
    set "USE_ENV_URL=S"
    set /p "USE_ENV_URL= Deseja reutilizar esta URL no build do APK? [S/N] (Padrao: S): "
    if /i "!USE_ENV_URL!"=="S" (
        call :start_cloudflare
        goto format_cloudflare_url
    )
    set "CLOUDFLARE_URL="
)

:: 3. Inicia o Cloudflare Quick Tunnel em janela dedicada
echo.
echo [*] Inicializando Cloudflare Quick Tunnel para obter URL publica...
call :start_cloudflare

:: 4. Aguarda e tenta capturar automaticamente a URL a partir do log
echo [*] Aguardando registro da URL publica pelo Cloudflare (ate 12s)...
call :poll_cloudflare_url

if not "!DETECTED_URL!"=="" (
    echo.
    echo [OK] URL do Cloudflare detectada automaticamente: !DETECTED_URL!
    set "CLOUDFLARE_URL=!DETECTED_URL!"
    set "CONFIRM_URL="
    set /p "CONFIRM_URL= Pressione ENTER para confirmar ou digite uma nova URL: "
    if not "!CONFIRM_URL!"=="" set "CLOUDFLARE_URL=!CONFIRM_URL!"
    goto format_cloudflare_url
)

:: 5. Se nao capturou automaticamente, instrui o usuario a colar da janela aberta
echo.
echo -------------------------------------------------------------------------------
echo   INSTRUCOES CLOUDFLARE QUICK TUNNEL:
echo   1. Olhe para a janela "Cloudflare Tunnel" que acabou de abrir.
echo   2. Localize a linha com https://...trycloudflare.com
echo   3. Copie o endereco e cole abaixo:
echo -------------------------------------------------------------------------------
set /p "CLOUDFLARE_URL= Digite ou cole a URL HTTPS gerada pelo Cloudflare: "

:format_cloudflare_url
:: Remove espacos e aspas
set "CLOUDFLARE_URL=%CLOUDFLARE_URL:"=%"
set "CLOUDFLARE_URL=%CLOUDFLARE_URL: =%"

if not defined CLOUDFLARE_URL (
    echo [!] Nenhuma URL informada. Digite uma URL valida para continuar.
    pause
    goto resolve_cloudflare_url
)

:: Garante prefixo https://
if not "%CLOUDFLARE_URL:~0,8%"=="https://" (
    if "%CLOUDFLARE_URL:~0,7%"=="http://" (
        echo [!] Convertendo http:// para https://...
        set "CLOUDFLARE_URL=https://%CLOUDFLARE_URL:~7%"
    ) else (
        set "CLOUDFLARE_URL=https://%CLOUDFLARE_URL%"
    )
)

:: Remove barra final se presente
if "%CLOUDFLARE_URL:~-1%"=="/" set "CLOUDFLARE_URL=%CLOUDFLARE_URL:~0,-1%"

:: Persiste CLOUDFLARE_URL no backend\.env para manter atualizado
powershell -NoProfile -Command "if (Test-Path '%PROJECT_DIR%backend\.env') { $c = Get-Content '%PROJECT_DIR%backend\.env'; if ($c -match '^CLOUDFLARE_URL=') { $c = $c -replace '^CLOUDFLARE_URL=.*', 'CLOUDFLARE_URL=%CLOUDFLARE_URL%' } else { $c += 'CLOUDFLARE_URL=%CLOUDFLARE_URL%' }; Set-Content -Path '%PROJECT_DIR%backend\.env' -Value $c }" 2>nul

echo [*] URL Publica do Cloudflare confirmada: %CLOUDFLARE_URL%
exit /b 0

:: -------------------------------------------------------------------------------
:: :poll_cloudflare_url -- Polling rapido do log para extracao do link trycloudflare
:: -------------------------------------------------------------------------------
:poll_cloudflare_url
set "DETECTED_URL="
for /l %%I in (1,1,12) do (
    if not defined DETECTED_URL (
        powershell -NoProfile -Command "Start-Sleep -Seconds 1"
        if exist "%PROJECT_DIR%tools\cloudflared.log" (
            for /f "usebackq tokens=*" %%U in (`powershell -NoProfile -Command "try { (Get-Content '%PROJECT_DIR%tools\cloudflared.log' -ErrorAction SilentlyContinue | Select-String -Pattern 'https://[a-zA-Z0-9-]+\.trycloudflare\.com').Matches[0].Value } catch {}"`) do (
                if not "%%U"=="" set "DETECTED_URL=%%U"
            )
        )
    )
)
exit /b 0

:: -------------------------------------------------------------------------------
:: OUTRAS FUNCOES AUXILIARES
:: -------------------------------------------------------------------------------
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
if not defined WAIT_TARGET_IP set "WAIT_TARGET_IP=127.0.0.1"
echo [2/3] Aguardando Backend Docker responder em http://%WAIT_TARGET_IP%:8000...
:loop_wait_django
powershell -NoProfile -Command "Start-Sleep -Seconds 3"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/health/' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } else { exit 1 } }" 2>nul
if errorlevel 1 (
    echo     ...Django ainda inicializando, aguardando...
    goto loop_wait_django
)
set "WAIT_TARGET_IP="
echo [OK] Django esta pronto e respondendo!
exit /b 0

:start_flutter_debug
echo.
echo [3/3] Iniciando o aplicativo Flutter em modo DEBUG...
cd /d "%PROJECT_DIR%frontend\tupi_lingo"
call flutter run --dart-define-from-file=.env
exit /b 0

:end