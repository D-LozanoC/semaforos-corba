# -*- coding: utf-8 -*-
"""
server.py - Servidor CORBA del sistema de semaforos inteligentes.

Implementa la interfaz traffic.TrafficService definida en el IDL.
Publica el objeto de dos maneras (lo que funcione):

  1. En el Naming Service (omniNames), con el nombre "TrafficService".
     -> Ideal para el despliegue en EC2.
  2. En un archivo IOR (server.ior), como respaldo.
     -> Ideal para correr en local sin montar omniNames.

ANTES de ejecutar hay que generar los stubs desde el IDL:

    omniidl -bpython -C. ../idl/traffic.idl

Eso crea el paquete `traffic` y `traffic__POA` en este directorio.

Ejecucion en local:
    python server.py

Ejecucion en EC2 (puerto fijo + IP publica para el IOR):
    python server.py -ORBendPoint giop:tcp::5000 \
                      -ORBendPointPublish giop:tcp:<IP_PUBLICA>:5000
"""

import sys
import os

from omniORB import CORBA, PortableServer
import CosNaming

# Stubs generados por omniidl a partir de traffic.idl
import traffic
import traffic__POA

import data


# ------------------------------------------------------------
# Implementacion (el "servant"): aqui vive la logica real.
# El cliente NO ve esto; solo ve el contrato IDL.
# ------------------------------------------------------------
class TrafficServiceImpl(traffic__POA.TrafficService):

    def list_intersections(self):
        """Devuelve la lista completa de intersecciones simuladas."""
        print("[servidor] list_intersections()")
        result = []
        for d in data.all_simulated():
            result.append(traffic.IntersectionInfo(
                d["id"], d["name"], d["lat"], d["lon"],
                d["vehicle_count"], d["congestion_level"],
                d["avg_wait_seconds"]))
        return result

    def get_intersection(self, int_id):
        """Devuelve una interseccion por id, o lanza IntersectionNotFound."""
        print("[servidor] get_intersection(%r)" % int_id)
        d = data.one_simulated(int_id)
        if d is None:
            raise traffic.IntersectionNotFound(
                "No existe la interseccion con id=%r" % int_id)
        return traffic.IntersectionInfo(
            d["id"], d["name"], d["lat"], d["lon"],
            d["vehicle_count"], d["congestion_level"],
            d["avg_wait_seconds"])


def _publish_in_naming_service(orb, obj_ref):
    """Intenta registrar el objeto en omniNames. Devuelve True si lo logra."""
    try:
        nc_obj = orb.resolve_initial_references("NameService")
        root_context = nc_obj._narrow(CosNaming.NamingContext)
        if root_context is None:
            print("[servidor] NameService no es un NamingContext valido.")
            return False
        name = [CosNaming.NameComponent("TrafficService", "")]
        try:
            root_context.bind(name, obj_ref)
        except CosNaming.NamingContext.AlreadyBound:
            root_context.rebind(name, obj_ref)
        print("[servidor] Registrado en omniNames como 'TrafficService'.")
        return True
    except Exception as e:  # noqa: BLE001  (didactico: capturamos todo)
        print("[servidor] No se pudo usar omniNames (%s)." % e)
        return False


def _publish_to_file(orb, obj_ref):
    """Escribe el IOR en server.ior para el fallback local."""
    ior = orb.object_to_string(obj_ref)
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "server.ior")
    with open(path, "w") as f:
        f.write(ior)
    print("[servidor] IOR escrito en %s" % path)


def main(argv):
    # 1. Inicializar el ORB (pasa los -ORB... del linea de comandos).
    orb = CORBA.ORB_init(argv, CORBA.ORB_ID)

    # 2. Obtener y activar el POA raiz.
    poa = orb.resolve_initial_references("RootPOA")
    poa_manager = poa._get_the_POAManager()
    poa_manager.activate()

    # 3. Crear el servant y obtener su referencia CORBA.
    servant = TrafficServiceImpl()
    obj_ref = servant._this()

    # 4. Publicar la referencia (naming service y/o archivo).
    _publish_in_naming_service(orb, obj_ref)
    _publish_to_file(orb, obj_ref)

    print("[servidor] TrafficService listo. Esperando invocaciones...")
    print("[servidor] (Ctrl+C para salir)")

    # 5. Quedarse atendiendo peticiones para siempre.
    try:
        orb.run()
    except KeyboardInterrupt:
        print("\n[servidor] Cerrando...")
        orb.shutdown(True)
        orb.destroy()


if __name__ == "__main__":
    main(sys.argv)
