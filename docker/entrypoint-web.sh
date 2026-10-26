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

# El servidor puede tardar unos segundos en registrar TrafficService en
# omniNames. depends_on NO espera a que el servicio este listo, solo a que el
# contenedor arranque, asi que reintentamos hasta que la app levante.
cd /app/web_client
n=0
until python app.py -ORBInitRef "NameService=corbaname::$SERVER_HOST:$NS_PORT"; do
  n=$((n + 1))
  if [ "$n" -ge 15 ]; then
    echo ">> [web] el servidor no respondio tras $n intentos; abortando."
    exit 1
  fi
  echo ">> [web] servidor aun no listo (intento $n); reintentando en 3s..."
  sleep 3
done
