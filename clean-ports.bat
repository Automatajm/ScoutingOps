@echo off
REM ========================================
REM LIMPIAR PUERTOS - DR Pest Control
REM ========================================
REM Script para limpiar puertos 8000 y 8080
REM Util cuando los servidores quedan colgados

echo.
echo ========================================
echo   LIMPIEZA DE PUERTOS
echo ========================================
echo.

set BACKEND_PORT=8000
set FRONTEND_PORT=8080

echo Buscando procesos en puerto %BACKEND_PORT%...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%BACKEND_PORT%"') do (
    echo   Matando proceso PID: %%a
    taskkill /F /PID %%a >nul 2>&1
)

echo Buscando procesos en puerto %FRONTEND_PORT%...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%FRONTEND_PORT%"') do (
    echo   Matando proceso PID: %%a
    taskkill /F /PID %%a >nul 2>&1
)

echo.
echo Puertos limpiados.
echo.
pause
