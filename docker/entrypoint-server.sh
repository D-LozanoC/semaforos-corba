#!/bin/sh
# ============================================================
#  entrypoint-server.sh - Arranque del contenedor SERVIDOR.
#  Arranca omniNames y luego el servidor CORBA.
#
#  Variables de entorno (con valores por defecto):
#    PUBLISH_HOST  host/IP que se publica en el IOR   (default: servidor)
#    IIOP_PORT     puerto IIOP del servidor           (default: 5000)
#    NS_PORT       puerto de omniNames                (default: 2809)
# ============================================================
set -e

PUBLISH_HOST="${PUBLISH_HOST:-servidor}"
IIOP_PORT="${IIOP_PORT:-5000}"
NS_PORT="${NS_PORT:-2809}"

echo ">> [server] omniNames en :$NS_PORT | IIOP :$IIOP_PORT | publica $PUBLISH_HOST"

# 1. Arrancar omniNames en segundo plano.
omniNames -start "$NS_PORT" -logdir /tmp >/tmp/omninames.log 2>&1 &

# 2. Esperar a que omniNames este listo.
sleep 3

# 3. Arrancar el servidor CORBA (en primer plano = proceso principal).
cd /app/server
exec python server.py \
  -ORBendPoint "giop:tcp::$IIOP_PORT" \
  -ORBendPointPublish "giop:tcp:$PUBLISH_HOST:$IIOP_PORT" \
  -ORBInitRef "NameService=corbaname::$PUBLISH_HOST:$NS_PORT"
