# -*- coding: utf-8 -*-
"""
app.py - OPCION B: interfaz web + cliente CORBA en el MISMO proceso.

Este unico programa Python:
  1. Sirve la pagina web (el mapa Leaflet) con render_template / Jinja2.
  2. Es cliente CORBA: invoca al servidor remoto por IIOP.

Asi no hace falta un intermediario separado ni GitHub Pages aparte,
y nos ahorramos CORS y el problema de 'mixed content' HTTPS.

ANTES de ejecutar hay que tener los stubs generados por omniidl
accesibles (run_web.sh lo configura).

Uso local:
    python app.py
    # abre http://localhost:8080

Uso en EC2 (resolviendo por Naming Service):
    python app.py -ORBInitRef NameService=corbaname::<host_naming>:2809
"""

import sys
import os

from flask import Flask, render_template, jsonify

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "common"))
sys.path.insert(0, os.path.join(HERE, "..", "server"))  # stubs + server.ior

from corba_client import TrafficClient  # noqa: E402

app = Flask(__name__)

# --- El cliente CORBA se crea UNA vez al arrancar el proceso ---
IOR_PATH = os.path.join(HERE, "..", "server", "server.ior")
corba = TrafficClient(argv=sys.argv, ior_path=IOR_PATH)


# ------------------------------------------------------------
#  Rutas que SIRVEN LA WEB (rol "cliente/servidor web")
# ------------------------------------------------------------
@app.route("/")
def index():
    """Devuelve la pagina con el mapa Leaflet."""
    return render_template("index.html")


# ------------------------------------------------------------
#  Rutas API que por dentro INVOCAN CORBA (rol "cliente CORBA")
#  El JS del navegador llama a estas rutas; estas rutas llaman
#  al servidor CORBA. Mismo proceso Python para ambas cosas.
# ------------------------------------------------------------
@app.route("/api/intersections")
def api_list():
    return jsonify(corba.list_intersections())


@app.route("/api/intersections/<int_id>")
def api_one(int_id):
    return jsonify(corba.get_intersection(int_id))


if __name__ == "__main__":
    # host=0.0.0.0 para que sea accesible desde fuera de EC2.
    app.run(host="0.0.0.0", port=8080, debug=True, use_reloader=False)
