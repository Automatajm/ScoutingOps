@echo off
REM ========================================
REM BUILD DEVELOPMENT - DR Pest Control
REM ========================================

echo.
echo ========================================
echo   DR PEST CONTROL - BUILD DEVELOPMENT
echo ========================================
echo.

set FLAVOR=development
set BACKEND_PORT=8000
set FRONTEND_PORT=8080
set CLIENT_NAME=drpestcontrol

REM ========================================
REM 1. BACKEND
REM ========================================
echo.
echo [1/4] Verificando Backend...

if not exist "backend\node_modules" (
    echo   Instalando dependencias...
    cd backend
    call npm install
    cd ..
)

REM Verificar cookie-parser y jsonwebtoken
cd backend
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
REM 2. FRONTEND
REM ========================================
echo.
echo [2/4] Compilando Frontend...

cd frontend
echo   Limpiando...
call flutter clean

echo   Descargando dependencias...
call flutter pub get

echo   Compilando para web (development)...
echo   Esto puede tomar 1-2 minutos...

call flutter build web --dart-define=FLAVOR=%FLAVOR% --release

if errorlevel 1 (
    echo.
    echo   ERROR en compilacion de Flutter
    cd ..
    pause
    exit /b 1
)

echo   Frontend compilado exitosamente
cd ..

REM ========================================
REM 3. SSL
REM ========================================
echo.
echo [3/4] Verificando SSL...

if exist "key.pem" (
    if exist "cert.pem" (
        echo   Certificados SSL encontrados
        set USE_SSL=true
        set PROTOCOL=https
    ) else (
        echo   Certificados SSL no encontrados - usando HTTP
        set USE_SSL=false
        set PROTOCOL=http
    )
) else (
    echo   Certificados SSL no encontrados - usando HTTP
    set USE_SSL=false
    set PROTOCOL=http
)

REM ========================================
REM 4. INICIAR SERVIDORES
REM ========================================
echo.
echo [4/4] Iniciando servidores...

REM Limpiar puertos
echo   Limpiando puertos...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%BACKEND_PORT%"') do taskkill /F /PID %%a 2>nul
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%FRONTEND_PORT%"') do taskkill /F /PID %%a 2>nul

timeout /t 1 >nul

REM Iniciar Backend usando npm run dev
echo   Iniciando Backend en puerto %BACKEND_PORT% (npm run dev)...
start "Backend-%CLIENT_NAME%" cmd /c "cd backend && npm run dev"

timeout /t 3 >nul

REM Iniciar Frontend
echo   Iniciando Frontend en puerto %FRONTEND_PORT%...

if "%USE_SSL%"=="true" (
    start "Frontend-%CLIENT_NAME%" cmd /c "cd frontend\build\web && http-server -p %FRONTEND_PORT% -S -C ..\..\..\cert.pem -K ..\..\..\key.pem -a 0.0.0.0 --cors"
) else (
    start "Frontend-%CLIENT_NAME%" cmd /c "cd frontend\build\web && http-server -p %FRONTEND_PORT% -a 0.0.0.0 --cors"
)

timeout /t 2 >nul

REM ========================================
REM INFORMACION
REM ========================================
echo.
echo ========================================
echo   SERVIDORES EJECUTANDOSE
echo ========================================
echo.
echo Entorno:
echo   Flavor: %FLAVOR%
echo   Cliente: %CLIENT_NAME%
echo   Script Backend: npm run dev
echo.
echo URLs de Acceso:
echo   App: %PROTOCOL%://%CLIENT_NAME%:%FRONTEND_PORT%
echo   Local: %PROTOCOL%://localhost:%FRONTEND_PORT%
echo   API: %PROTOCOL%://%CLIENT_NAME%:%BACKEND_PORT%
echo.
echo Funcionalidades:
echo   [OK] HttpOnly Cookies
echo   [OK] Persistencia de sesion
echo   [OK] CORS con credentials
echo   [OK] Logs completos habilitados
echo.
echo Controles:
echo   Para detener: Cerrar las ventanas de Backend y Frontend
echo   O presionar Ctrl+C en cada ventana
echo   O ejecutar: clean-ports.bat
echo.
echo ========================================
echo.
echo Los servidores estan corriendo en ventanas separadas.
echo Puedes cerrar esta ventana sin afectar los servidores.
echo.
pause