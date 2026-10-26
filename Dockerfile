# ============================================================
#  Dockerfile - Imagen unica para el proyecto Semaforos CORBA.
# ------------------------------------------------------------
#  Congela el entorno que funciona:
#    - Python 3.10 (unica version con wheel de omniorb-py)
#    - omniorb-py (binding CORBA) + Flask, por pip
#    - stubs generados desde el IDL en tiempo de build
#
#  La MISMA imagen sirve para dos roles, segun el comando:
#    - Servidor:  python server/server.py ...
#    - Web:       python web_client/app.py ...
#  (ver docker-compose.yml y DOCKER.md)
# ============================================================
FROM python:3.10-slim

# Evitar prompts de apt y buffering de Python.
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# Instala el binario omniNames (servicio de nombres). El paquete
# omniorb-nameserver arrastra sus librerias (libomniorb4-2, libomnithread4)
# como dependencias, asi que no hace falta listarlas.
RUN apt-get update && apt-get install -y --no-install-recommends \
        omniorb-nameserver \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar el binding CORBA y Flask.
RUN pip install --no-cache-dir omniorb-py Flask

# omniidl (de omniorb-py) tiene un shebang que apunta a /usr/local/bin/python,
# que en esta imagen ES el Python 3.10 oficial -> funciona directo, sin symlink.

# Copiar el codigo fuente.
COPY idl/ ./idl/
COPY server/ ./server/
COPY common/ ./common/
COPY web_client/ ./web_client/
COPY console_client/ ./console_client/
COPY docker/ ./docker/

# Generar los stubs desde el IDL (dentro de la imagen).
RUN cd server && omniidl -bpython -C. ../idl/traffic.idl

# Para que 'import traffic' y 'corba_client' se encuentren desde cualquier rol.
ENV PYTHONPATH=/app/server:/app/common

# Puertos: IIOP del servidor, omniNames, y la web.
EXPOSE 5000 2809 8080

# Por defecto arranca la web; docker-compose/los comandos lo sobreescriben.
CMD ["python", "web_client/app.py"]
