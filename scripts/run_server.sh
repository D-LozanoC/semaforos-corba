#!/usr/bin/env bash
# Arranca el servidor CORBA en LOCAL.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/server"

# Asegurar que los stubs existen.
if [ ! -d "traffic" ]; then
  echo ">> No hay stubs; generandolos primero..."
  bash "$ROOT/scripts/gen_stubs.sh"
fi

echo ">> Iniciando servidor CORBA (local)..."
python server.py "$@"
