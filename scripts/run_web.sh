#!/usr/bin/env bash
# Arranca la OPCION B: Flask que sirve la web Y es cliente CORBA.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Los stubs viven en server/; los exponemos por PYTHONPATH.
export PYTHONPATH="$ROOT/server:$ROOT/common:$PYTHONPATH"

cd "$ROOT/web_client"
echo ">> Iniciando interfaz web + cliente CORBA en http://localhost:8080"
python app.py "$@"
