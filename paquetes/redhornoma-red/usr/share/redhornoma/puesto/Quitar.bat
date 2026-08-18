@echo off
REM ====================================================================
REM  Quitar.bat - Dejar esta computadora como estaba antes.
REM
REM  Se abre con DOBLE CLIC, al terminar la jornada en el centro.
REM
REM  Lo mismo que Instalar.bat: se copia a una carpeta local primero,
REM  porque cmd.exe no sabe trabajar dentro de una ruta \\servidor\...
REM ====================================================================
setlocal
title Quitar el puesto del centro - RedHornoma

set "DESTINO=%TEMP%\redhornoma-puesto"
if not exist "%DESTINO%" mkdir "%DESTINO%" >nul 2>&1
copy /Y "%~dp0quitar-puesto.ps1" "%DESTINO%\" >nul 2>&1

if not exist "%DESTINO%\quitar-puesto.ps1" (
  echo.
  echo    No se pudo copiar el desinstalador.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DESTINO%\quitar-puesto.ps1"

echo.
pause
