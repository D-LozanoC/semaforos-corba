#!/usr/bin/env bash
# Ejecuta el cliente de consola (CORBA directo).
#   bash run_console.sh            -> lista todas
#   bash run_console.sh INT-03     -> consulta una
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT/server:$ROOT/common:$PYTHONPATH"
cd "$ROOT/console_client"
python console.py "$@"
