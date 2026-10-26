#!/usr/bin/env bash
# ============================================================
#  start_server_ec2.sh - Arranca el SERVIDOR CORBA en EC2-A.
# ------------------------------------------------------------
#  Fija el puerto IIOP y publica la IP PUBLICA de EC2-A para que
#  el IOR sea alcanzable desde la otra instancia.
#
#  Variables de entorno:
#    PUBLIC_IP   IP publica (o elastica) de EC2-A   (OBLIGATORIA)
#    PRIVATE_IP  IP privada de EC2-A                (default: PUBLIC_IP)
#    IIOP_PORT   puerto IIOP del servidor           (default: 5000)
#    NS_PORT     puerto de omniNames                (default: 2809)
#
#  Uso:
#    export PUBLIC_IP=<ip_publica_ec2_a>
#    export PRIVATE_IP=<ip_privada_ec2_a>
#    bash deploy/start_server_ec2.sh
# ============================================================
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${PUBLIC_IP:?Debes exportar PUBLIC_IP con la IP publica de EC2-A}"
PRIVATE_IP="${PRIVATE_IP:-$PUBLIC_IP}"
IIOP_PORT="${IIOP_PORT:-5000}"
NS_PORT="${NS_PORT:-2809}"

echo ">> EC2-A  PUBLIC_IP=$PUBLIC_IP  PRIVATE_IP=$PRIVATE_IP  IIOP=$IIOP_PORT  NS=$NS_PORT"

# Activar el venv si existe (ajusta la ruta si usas otra).
if [ -f "$HOME/venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$HOME/venv/bin/activate"
fi

# Asegurar stubs.
if [ ! -d "$ROOT/server/traffic" ]; then
  echo ">> Generando stubs..."
  bash "$ROOT/scripts/gen_stubs.sh"
fi

# Arrancar omniNames si no esta corriendo (log en /tmp).
if ! pgrep -x omniNames >/dev/null 2>&1; then
  echo ">> Arrancando omniNames en $NS_PORT..."
  omniNames -start "$NS_PORT" -logdir /tmp >/tmp/omninames.log 2>&1 &
  sleep 2
fi

echo ">> Arrancando servidor CORBA..."
cd "$ROOT/server"
exec python server.py \
  -ORBendPoint "giop:tcp::$IIOP_PORT" \
  -ORBendPointPublish "giop:tcp:$PUBLIC_IP:$IIOP_PORT" \
  -ORBInitRef "NameService=corbaname::$PRIVATE_IP:$NS_PORT"
