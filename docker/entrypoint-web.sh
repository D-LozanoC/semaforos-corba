#!/bin/sh
# ============================================================
#  entrypoint-web.sh - Arranque del contenedor WEB (Flask).
#  Se conecta al servidor CORBA via el Naming Service.
#
#  Variables de entorno (con valores por defecto):
#    SERVER_HOST  host/IP donde corre omniNames        (default: servidor)
#    NS_PORT      puerto de omniNames                  (default: 2809)
#    WEB_PORT     puerto HTTP de Flask                 (default: 8080)
# ============================================================
set -e

SERVER_HOST="${SERVER_HOST:-servidor}"
NS_PORT="${NS_PORT:-2809}"

echo ">> [web] conectando al NameService en $SERVER_HOST:$NS_PORT | web :${WEB_PORT:-8080}"

cd /app/web_client
exec python app.py \
  -ORBInitRef "NameService=corbaname::$SERVER_HOST:$NS_PORT"
