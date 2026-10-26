@echo off
REM ============================================================
REM  gen_stubs.bat - Genera los stubs Python desde el IDL.
REM  Equivalente Windows de scripts/gen_stubs.sh
REM  Ejecutar en Anaconda Prompt (o CMD) con el entorno activado.
REM ============================================================
setlocal
REM Raiz del proyecto = carpeta padre de este script.
set "ROOT=%~dp0.."

echo ^>^> Generando stubs desde idl\traffic.idl ...
cd /d "%ROOT%\server"
omniidl -bpython -C. "%ROOT%\idl\traffic.idl"
if errorlevel 1 (
  echo ^>^> ERROR: fallo omniidl. Revisa que omniORB este instalado y en el PATH.
  exit /b 1
)
echo ^>^> Listo. Se crearon los paquetes 'traffic' y 'traffic__POA' en server\
endlocal
