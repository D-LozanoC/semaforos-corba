@echo off
REM ============================================================
REM  run_console.bat - Cliente de consola (CORBA directo).
REM  Equivalente Windows de scripts/run_console.sh
REM  Uso:
REM    run_console.bat            -> lista todas las intersecciones
REM    run_console.bat INT-03     -> consulta una interseccion
REM ============================================================
setlocal
set "ROOT=%~dp0.."

REM En Windows el separador de rutas en PYTHONPATH es ';' (no ':').
set "PYTHONPATH=%ROOT%\server;%ROOT%\common;%PYTHONPATH%"

cd /d "%ROOT%\console_client"
python console.py %*
endlocal
