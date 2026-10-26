@echo off
REM ============================================================
REM  run_web.bat - OPCION B: Flask sirve la web Y es cliente CORBA.
REM  Equivalente Windows de scripts/run_web.sh
REM  Uso:  run_web.bat  [opciones -ORB...]
REM ============================================================
setlocal
set "ROOT=%~dp0.."

REM Los stubs viven en server\; los exponemos por PYTHONPATH.
REM En Windows el separador de rutas en PYTHONPATH es ';' (no ':').
set "PYTHONPATH=%ROOT%\server;%ROOT%\common;%PYTHONPATH%"

cd /d "%ROOT%\web_client"
echo ^>^> Iniciando interfaz web + cliente CORBA en http://localhost:8080
python app.py %*
endlocal
