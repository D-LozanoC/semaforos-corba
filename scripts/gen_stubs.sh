#!/usr/bin/env bash
# Genera los stubs Python a partir del contrato IDL.
# Se dejan en server/ para que server, cliente web y consola los compartan.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ">> Generando stubs desde idl/traffic.idl ..."
cd "$ROOT/server"
omniidl -bpython -C. "$ROOT/idl/traffic.idl"
echo ">> Listo. Se crearon los paquetes 'traffic' y 'traffic__POA' en server/"
