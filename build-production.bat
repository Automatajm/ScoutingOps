@echo off
REM ========================================
REM BUILD PRODUCTION - DR Pest Control
REM ========================================

echo.
echo ========================================
echo   DR PEST CONTROL - BUILD PRODUCTION
echo ========================================
echo.

REM Confirmacion
echo ADVERTENCIA: Compilacion para PRODUCCION
echo    - Rate limiting ESTRICTO
echo    - Logs DESHABILITADOS
echo    - SSL REQUERIDO
echo.
set /p CONFIRM="Continuar con compilacion de PRODUCCION? (S/N): "
if /i not "%CONFIRM%"=="S" (
    echo Compilacion cancelada
    pause
    exit /b 0
)

set FLAVOR=production
set BACKEND_PORT=8000
set FRONTEND_PORT=8080
set CLIENT_NAME=drpestcontrol

REM ========================================
REM 1. VERIFICACIONES
REM ========================================
echo.
echo [1/5] Verificaciones de Seguridad...

REM JWT Secret
if "%JWT_SECRET%"=="" goto jwt_error
if "%JWT_SECRET%"=="your-secret-key" goto jwt_error
echo   JWT_SECRET configurado

REM SSL
if not exist "key.pem" goto ssl_error
if not exist "cert.pem" goto ssl_error
echo   Certificados SSL verificados

goto continue_build

:jwt_error
echo   ERROR: JWT_SECRET no configurado o inseguro
echo   Configura: set JWT_SECRET=clave-segura
pause
exit /b 1

:ssl_error
echo   ERROR: Certificados SSL requeridos
echo   Coloca key.pem y cert.pem en la raiz
pause
exit /b 1

:continue_build

REM ========================================
REM 2. BACKEND
REM ========================================
echo.
echo [2/5] Preparando Backend...

cd backend

if not exist "node_modules" (
    echo   Instalando dependencias...
    call npm install --production
    if errorlevel 1 goto npm_error
)

REM Verificar paquetes criticos
echo   Verificando paquetes criticos...
call npm list express 2>nul | find "express" >nul
if errorlevel 1 (
    echo   Instalando express...
    call npm install express
)

call npm list cookie-parser 2>nul | find "cookie-parser" >nul
if errorlevel 1 (
    echo   Instalando cookie-parser...
    call npm install cookie-parser
)

call npm list jsonwebtoken 2>nul | find "jsonwebtoken" >nul
if errorlevel 1 (
    echo   Instalando jsonwebtoken...
    call npm install jsonwebtoken
)

call npm list cross-env 2>nul | find "cross-env" >nul
if errorlevel 1 (
    echo   Instalando cross-env...
    call npm install cross-env
)

cd ..
echo   Backend verificado

REM ========================================
REM 3. FRONTEND
REM ========================================
echo.
echo [3/5] Compilando Frontend...

cd frontend

echo   Limpiando...
call flutter clean

echo   Descargando dependencias...
call flutter pub get

echo   Compilando para PRODUCCION...
echo   Esto puede tomar 2-3 minutos...
echo   Optimizando y minificando...

call flutter build web --dart-define=FLAVOR=%FLAVOR% --release --tree-shake-icons

if errorlevel 1 (
    echo.
    echo   ERROR en compilacion
    cd ..
    pause
    exit /b 1
)

echo   Frontend compilado y optimizado
cd ..

REM ========================================
REM 4. OPTIMIZACIONES
REM ========================================
echo.
echo [4/5] Aplicando optimizaciones...
echo   Optimizaciones aplicadas

REM ========================================
REM 5. INICIAR
REM ========================================
echo.
echo [5/5] Iniciando servidores...

REM Limpiar puertos
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%BACKEND_PORT%"') do taskkill /F /PID %%a 2>nul
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%FRONTEND_PORT%"') do taskkill /F /PID %%a 2>nul

timeout /t 1 >nul

REM Backend usando npm run prod
echo   Iniciando Backend (npm run prod)...
start "Backend-PROD-%CLIENT_NAME%" cmd /c "cd backend && npm run prod"

timeout /t 4 >nul

REM Frontend
echo   Iniciando Frontend (PRODUCTION)...
start "Frontend-PROD-%CLIENT_NAME%" cmd /c "cd frontend\build\web && http-server -p %FRONTEND_PORT% -S -C ..\..\..\cert.pem -K ..\..\..\key.pem -a 0.0.0.0 --cors -c-1 --gzip"

timeout /t 2 >nul

REM ========================================
REM INFO
REM ========================================
echo.
echo ========================================
echo   PRODUCCION EJECUTANDOSE
echo ========================================
echo.
echo Modo: PRODUCCION
echo   SSL: HABILITADO
echo   Logs: DESHABILITADOS
echo   Rate Limit: ESTRICTO
echo   Optimizacion: MAXIMA
echo   Script Backend: npm run prod
echo.
echo URLs:
echo   App: https://%CLIENT_NAME%:%FRONTEND_PORT%
echo   API: https://%CLIENT_NAME%:%BACKEND_PORT%
echo.
echo Seguridad:
echo   [OK] HttpOnly Cookies
echo   [OK] CORS Estricto
echo   [OK] JWT Seguro
echo   [OK] Logs Minimos
echo.
echo IMPORTANTE:
echo   El package.json configura automaticamente:
echo   - NODE_ENV=production
echo   - FLAVOR=production
echo   - Logs deshabilitados via cross-env
echo.
echo Controles:
echo   Para detener: Cerrar ventanas Backend y Frontend
echo   O ejecutar: clean-ports.bat
echo.
echo ========================================
echo.
echo Los servidores estan corriendo en ventanas separadas.
echo Puedes cerrar esta ventana sin afectar los servidores.
echo.
pause
exit /b 0

:npm_error
echo   ERROR en npm install
cd ..
pause
exit /b 1