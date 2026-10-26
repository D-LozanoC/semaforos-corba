@echo off
REM ============================================================
REM  run_server.bat - Arranca el servidor CORBA en LOCAL.
REM  Equivalente Windows de scripts/run_server.sh
REM  Uso:  run_server.bat  [opciones -ORB...]
REM ============================================================
setlocal
set "ROOT=%~dp0.."
cd /d "%ROOT%\server"

REM Asegurar que los stubs existen (la carpeta traffic\).
if not exist "traffic\" (
  echo ^>^> No hay stubs; generandolos primero...
  call "%ROOT%\scripts\gen_stubs.bat"
  if errorlevel 1 exit /b 1
)

echo ^>^> Iniciando servidor CORBA (local)...
python server.py %*
endlocal
