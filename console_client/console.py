# -*- coding: utf-8 -*-
"""
console.py - Cliente de CONSOLA que habla CORBA directo.

Este cliente demuestra el punto clave del proyecto: un cliente
completamente distinto del navegador invoca EL MISMO contrato IDL,
sin pasar por Flask ni por HTTP.

Requiere los stubs generados por omniidl accesibles en el PYTHONPATH.
En este proyecto, el script run_console.sh se encarga de eso.

Uso:
    python console.py                 # lista todas las intersecciones
    python console.py INT-03          # consulta una interseccion
    python console.py INT-03 -ORBInitRef NameService=corbaname::<host>:2809
"""

import sys
import os

# Permitir importar common/ y los stubs generados.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "common"))
sys.path.insert(0, os.path.join(HERE, "..", "server"))  # stubs + server.ior

from corba_client import TrafficClient  # noqa: E402


def print_one(d):
    if "error" in d:
        print("  ERROR: %s" % d["error"])
        return
    print("  %s  |  %s" % (d["id"], d["name"]))
    print("     vehiculos: %-4d  congestion: %-6s  espera: %ds"
          % (d["vehicle_count"], d["congestion_level"], d["avg_wait_seconds"]))
    print("     coords: (%.4f, %.4f)" % (d["lat"], d["lon"]))


def main():
    ior_path = os.path.join(HERE, "..", "server", "server.ior")

    # Separar un posible id (primer arg que no empiece por "-ORB")
    int_id = None
    orb_args = [sys.argv[0]]
    for a in sys.argv[1:]:
        if a.startswith("-ORB") or (orb_args and orb_args[-1].startswith("-ORB")):
            orb_args.append(a)
        elif int_id is None:
            int_id = a
        else:
            orb_args.append(a)

    client = TrafficClient(argv=orb_args, ior_path=ior_path)

    print("=" * 60)
    if int_id:
        print("Consulta de interseccion: %s" % int_id)
        print("=" * 60)
        print_one(client.get_intersection(int_id))
    else:
        print("Listado de intersecciones (via CORBA)")
        print("=" * 60)
        for d in client.list_intersections():
            print_one(d)
            print("-" * 60)


if __name__ == "__main__":
    main()
