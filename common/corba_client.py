# -*- coding: utf-8 -*-
"""
corba_client.py - Logica compartida para CONECTARSE al servidor CORBA.

Tanto el cliente web (Flask) como el cliente de consola usan esto,
para no repetir el codigo de resolucion de la referencia remota.

Estrategia de conexion:
  1. Si se pasa un IOR por string/archivo, usarlo (modo local simple).
  2. Si no, resolver "TrafficService" en el Naming Service (modo EC2).
"""

import os

from omniORB import CORBA
import CosNaming

import traffic  # stubs generados por omniidl


class TrafficClient(object):
    """Envoltorio sencillo alrededor de la referencia CORBA remota."""

    def __init__(self, argv=None, ior_path=None):
        self._orb = CORBA.ORB_init(argv or [], CORBA.ORB_ID)
        self._service = self._resolve(ior_path)

    def _resolve(self, ior_path):
        # --- Opcion 1: IOR por archivo (fallback local) ---
        if ior_path and os.path.exists(ior_path):
            with open(ior_path) as f:
                ior = f.read().strip()
            obj = self._orb.string_to_object(ior)
            svc = obj._narrow(traffic.TrafficService)
            if svc is not None:
                print("[cliente] Conectado via IOR de archivo.")
                return svc

        # --- Opcion 2: Naming Service (omniNames) ---
        try:
            nc_obj = self._orb.resolve_initial_references("NameService")
            root = nc_obj._narrow(CosNaming.NamingContext)
            name = [CosNaming.NameComponent("TrafficService", "")]
            obj = root.resolve(name)
            svc = obj._narrow(traffic.TrafficService)
            if svc is not None:
                print("[cliente] Conectado via omniNames.")
                return svc
        except Exception as e:  # noqa: BLE001
            print("[cliente] Fallo omniNames: %s" % e)

        raise RuntimeError(
            "No se pudo localizar TrafficService. "
            "Verifica que el servidor este corriendo y que el IOR "
            "o el Naming Service sean accesibles.")

    # ---- Metodos que exponen las operaciones remotas como dicts ----

    def list_intersections(self):
        out = []
        for i in self._service.list_intersections():
            out.append(self._to_dict(i))
        return out

    def get_intersection(self, int_id):
        try:
            info = self._service.get_intersection(int_id)
            return self._to_dict(info)
        except traffic.IntersectionNotFound as e:
            return {"error": e.reason}

    @staticmethod
    def _to_dict(i):
        return {
            "id": i.id,
            "name": i.name,
            "lat": i.lat,
            "lon": i.lon,
            "vehicle_count": i.vehicle_count,
            "congestion_level": i.congestion_level,
            "avg_wait_seconds": i.avg_wait_seconds,
        }
