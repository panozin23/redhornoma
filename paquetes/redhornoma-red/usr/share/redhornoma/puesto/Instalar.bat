@echo off
REM ====================================================================
REM  Instalar.bat - Convertir esta computadora en un puesto del centro.
REM
REM  Se abre con DOBLE CLIC. No hay nada que escribir aqui.
REM
REM  POR QUE ESTE ARCHIVO EXISTE Y NO SE LLAMA DIRECTO AL .ps1
REM
REM  1 - Windows no deja ejecutar un .ps1 con doble clic: lo abre en el
REM      Bloc de notas. Hace falta llamarlo desde aqui con -ExecutionPolicy
REM      Bypass, que vale SOLO para esta ejecucion y no cambia nada del
REM      equipo.
REM
REM  2 - Esto se lanza desde una carpeta compartida (\\servidor\INSTALAR).
REM      cmd.exe NO sabe trabajar en rutas \\... : avisa con
REM      "UNC paths are not supported" y se planta en C:\Windows, donde el
REM      guion ya no esta. Por eso lo primero es copiarse a una carpeta
REM      local y seguir desde alli.
REM ====================================================================
setlocal
title Instalar puesto del centro - RedHornoma

set "DESTINO=%TEMP%\redhornoma-puesto"
if not exist "%DESTINO%" mkdir "%DESTINO%" >nul 2>&1

REM  El %~dp0 es la carpeta de ESTE archivo, y funciona tambien en \\...
copy /Y "%~dp0instalar-puesto.ps1" "%DESTINO%\" >nul 2>&1
if not exist "%DESTINO%\instalar-puesto.ps1" (
  echo.
  echo    No se pudo copiar el instalador.
  echo    Vuelve a abrir la carpeta del servidor e intentalo de nuevo.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DESTINO%\instalar-puesto.ps1"

echo.
pause
