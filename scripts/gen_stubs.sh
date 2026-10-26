#!/usr/bin/env bash
# Genera los stubs Python a partir del contrato IDL.
# Se dejan en server/ para que server, cliente web y consola los compartan.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ">> Generando stubs desde idl/traffic.idl ..."
cd "$ROOT/server"

# Elegir como invocar omniidl segun el entorno:
#  - Si estamos en un venv con omniorb-py (pip), su script 'omniidl' tiene un
#    shebang que no carga el site-packages del venv; hay que lanzarlo con el
#    'python' del venv para que encuentre el modulo nativo _omniidl.
#  - En instalaciones del sistema (apt), 'omniidl' del PATH funciona directo.
if [ -n "$VIRTUAL_ENV" ] && [ -x "$VIRTUAL_ENV/bin/omniidl" ]; then
  python "$VIRTUAL_ENV/bin/omniidl" -bpython -C. "$ROOT/idl/traffic.idl"
else
  omniidl -bpython -C. "$ROOT/idl/traffic.idl"
fi

echo ">> Listo. Se crearon los paquetes 'traffic' y 'traffic__POA' en server/"
