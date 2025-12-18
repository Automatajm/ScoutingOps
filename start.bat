@echo off
REM ========================================
REM START - DR Pest Control
REM ========================================
REM Script para INICIAR sin recompilar
REM Uso: start.bat [development|staging|production]

set FLAVOR=%1
if "%FLAVOR%"=="" set FLAVOR=development

echo.
echo ========================================
echo   DR PEST CONTROL - QUICK START
echo ========================================
echo.
echo Flavor: %FLAVOR%

set BACKEND_PORT=8000
set FRONTEND_PORT=8080
set CLIENT_NAME=drpestcontrol

REM Determinar npm script a usar
if "%FLAVOR%"=="production" (
    set NPM_SCRIPT=prod
) else if "%FLAVOR%"=="staging" (
    set NPM_SCRIPT=staging
) else (
    set NPM_SCRIPT=dev
)

REM ========================================
REM VERIFICACIONES
REM ========================================
echo.
echo Verificando archivos compilados...

if not exist "frontend\build\web\index.html" (
    echo   ERROR: No hay build de frontend
    echo   Ejecuta primero: build-development.bat
    pause
    exit /b 1
)

echo   Build de frontend encontrado

if not exist "backend\server.js" (
    echo   ERROR: backend\server.js no encontrado
    pause
    exit /b 1
)

echo   Backend encontrado

REM SSL
if exist "key.pem" (
    if exist "cert.pem" (
        set USE_SSL=true
        set PROTOCOL=https
        echo   SSL habilitado
    ) else (
        set USE_SSL=false
        set PROTOCOL=http
        echo   SSL deshabilitado (HTTP)
    )
) else (
    set USE_SSL=false
    set PROTOCOL=http
    echo   SSL deshabilitado (HTTP)
)

REM ========================================
REM LIMPIAR PUERTOS
REM ========================================
echo.
echo Limpiando puertos...

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%BACKEND_PORT%"') do taskkill /F /PID %%a 2>nul
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%FRONTEND_PORT%"') do taskkill /F /PID %%a 2>nul

timeout /t 1 >nul
echo   Puertos liberados

REM ========================================
REM INICIAR SERVIDORES
REM ========================================
echo.
echo Iniciando servidores...

REM Backend usando npm run
echo   Iniciando Backend (npm run %NPM_SCRIPT%)...
start "Backend-%CLIENT_NAME%" cmd /c "cd backend && npm run %NPM_SCRIPT%"

timeout /t 3 >nul

REM Frontend
echo   Iniciando Frontend (%FLAVOR%)...

if "%USE_SSL%"=="true" (
    start "Frontend-%CLIENT_NAME%" cmd /c "cd frontend\build\web && http-server -p %FRONTEND_PORT% -S -C ..\..\..\cert.pem -K ..\..\..\key.pem -a 0.0.0.0 --cors -c-1"
) else (
    start "Frontend-%CLIENT_NAME%" cmd /c "cd frontend\build\web && http-server -p %FRONTEND_PORT% -a 0.0.0.0 --cors -c-1"
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
echo Entorno: %FLAVOR%
echo Cliente: %CLIENT_NAME%
echo Protocolo: %PROTOCOL%
echo Script Backend: npm run %NPM_SCRIPT%
echo.
echo URLs de Acceso:
echo   App: %PROTOCOL%://%CLIENT_NAME%:%FRONTEND_PORT%
echo   Local: %PROTOCOL%://localhost:%FRONTEND_PORT%
echo   API: %PROTOCOL%://%CLIENT_NAME%:%BACKEND_PORT%/api
echo.
echo Funcionalidades:
echo   [OK] HttpOnly Cookies
echo   [OK] Persistencia de sesion
echo   [OK] CORS con credentials
echo   [OK] Variables configuradas via npm
echo.
echo Controles:
echo   Para detener: Cerrar las ventanas de Backend y Frontend
echo.
echo ========================================
echo.
echo Los servidores estan corriendo en ventanas separadas.
echo Puedes cerrar esta ventana.
echo.
pause