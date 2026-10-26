#!/usr/bin/env bash
# ============================================================
#  start_web_ec2.sh - Arranca FLASK (web + cliente CORBA) en EC2-B.
# ------------------------------------------------------------
#  Se conecta al servidor CORBA de EC2-A a traves del Naming
#  Service (omniNames) que corre en EC2-A.
#
#  Variables de entorno:
#    SERVER_IP   IP publica de EC2-A (donde corre omniNames)  (OBLIGATORIA)
#    NS_PORT     puerto de omniNames en EC2-A                 (default: 2809)
#    WEB_PORT    puerto HTTP de Flask                         (default: 8080)
#
#  Uso:
#    export SERVER_IP=<ip_publica_ec2_a>
#    bash deploy/start_web_ec2.sh
#    # luego abre  http://<ip_publica_ec2_b>:8080
# ============================================================
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${SERVER_IP:?Debes exportar SERVER_IP con la IP publica de EC2-A}"
NS_PORT="${NS_PORT:-2809}"
WEB_PORT="${WEB_PORT:-8080}"

echo ">> EC2-B  SERVER_IP=$SERVER_IP  NS=$NS_PORT  WEB=$WEB_PORT"

# Activar el venv si existe.
if [ -f "$HOME/venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$HOME/venv/bin/activate"
fi

# Asegurar stubs (la web tambien los necesita).
if [ ! -d "$ROOT/server/traffic" ]; then
  echo ">> Generando stubs..."
  bash "$ROOT/scripts/gen_stubs.sh"
fi

export WEB_PORT   # app.py lo lee para el puerto (ver nota en DEPLOY.md)
export PYTHONPATH="$ROOT/server:$ROOT/common:$PYTHONPATH"

echo ">> Arrancando Flask (web + cliente CORBA)..."
cd "$ROOT/web_client"
exec python app.py -ORBInitRef "NameService=corbaname::$SERVER_IP:$NS_PORT"
