# -*- coding: utf-8 -*-
"""
data.py - Datos simulados de intersecciones de Bogota.

No hay sensores reales: generamos trafico aleatorio pero
realista. El objetivo del proyecto es demostrar CORBA, no
modelar trafico de verdad.
"""

import random

# Intersecciones reales de Bogota con coordenadas de los cruces viales.
# (lat, lon) en grados decimales (WGS84), ubicadas sobre el cruce real.
INTERSECTIONS = [
    {"id": "INT-01", "name": "Calle 26 con Av. Caracas",
     "lat": 4.615405, "lon": -74.072835},

    {"id": "INT-02", "name": "Autopista Norte con Calle 100",
     "lat": 4.686930, "lon": -74.057221},

    {"id": "INT-03", "name": "Av. Boyaca con Calle 80",
     "lat": 4.695338, "lon": -74.089169},

    {"id": "INT-04", "name": "Carrera 7 con Calle 72",
     "lat": 4.654865, "lon": -74.055406},

    {"id": "INT-05", "name": "Av. 68 con Calle 13",
     "lat": 4.637347, "lon": -74.118357},

    {"id": "INT-06", "name": "Av Cali con Av Americas",
     "lat":4.640483, "lon": -74.156356},

    {"id": "INT-07", "name": "Av. Suba con Calle 127",
     "lat": 4.710986, "lon": -74.072093},

    {"id": "INT-08", "name": "NQS con Av. Primero de Mayo",
     "lat": 4.596120, "lon": -74.113509},
]


def _congestion_from_count(count):
    """Clasifica el nivel de congestion segun el numero de vehiculos."""
    if count < 25:
        return "BAJO"
    if count < 60:
        return "MEDIO"
    return "ALTO"


def simulate(base):
    """Genera una lectura de trafico simulada para una interseccion.

    `base` es el dict estatico (id, name, lat, lon). Devolvemos un
    dict completo con los campos dinamicos recien 'medidos'.
    """
    count = random.randint(5, 95)
    level = _congestion_from_count(count)
    # La espera promedio crece con la congestion.
    wait = {"BAJO": random.randint(10, 25),
            "MEDIO": random.randint(25, 60),
            "ALTO": random.randint(60, 120)}[level]
    return {
        "id": base["id"],
        "name": base["name"],
        "lat": base["lat"],
        "lon": base["lon"],
        "vehicle_count": count,
        "congestion_level": level,
        "avg_wait_seconds": wait,
    }


def all_simulated():
    """Devuelve una lectura simulada de TODAS las intersecciones."""
    return [simulate(b) for b in INTERSECTIONS]


def one_simulated(int_id):
    """Devuelve una lectura simulada de UNA interseccion, o None."""
    for b in INTERSECTIONS:
        if b["id"] == int_id:
            return simulate(b)
    return None
