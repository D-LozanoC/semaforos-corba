# 🐳 Dockerizar el proyecto — paso a paso desde cero

Esta guía empaqueta todo el proyecto (servidor CORBA + web) en una imagen
Docker, para no volver a pelear con la configuración del entorno (Python 3.10,
`omniorb-py`, stubs, symlinks...). Lo probamos **en local** y luego la misma
imagen sirve para AWS.

> **Idea clave:** una **sola imagen**, **dos roles**. El mismo contenedor
> arranca como *servidor* o como *web* según el comando que reciba. En local,
> `docker compose` levanta ambos a la vez.

---

## 1. Instalar Docker (en WSL / Ubuntu)

Si ya tienes Docker (`docker --version` responde), salta al paso 2.

```bash
# Instalar Docker Engine
sudo apt update
sudo apt install -y docker.io docker-compose-v2

# Permitir usar docker sin sudo (opcional pero comodo)
sudo usermod -aG docker $USER
# Cierra y vuelve a abrir la terminal para que tome el grupo.

# Arrancar el servicio (en WSL a veces hay que hacerlo a mano)
sudo service docker start

# Verificar
docker --version
docker compose version
```

> 💡 Si usas **Docker Desktop** en Windows con integración WSL, el comando
> `docker` ya está disponible en Ubuntu y no necesitas instalar nada aquí.

---

## 2. Clonar el proyecto (si no lo tienes)

```bash
cd ~
git clone https://github.com/D-LozanoC/semaforos-corba.git
cd ~/semaforos-corba
```

> Con Docker **no** necesitas crear venv, ni instalar omniORB, ni generar
> stubs a mano: todo eso ocurre **dentro** de la imagen al construirla.

---

## 3. Construir y levantar TODO con un comando

```bash
docker compose up --build
```

Esto:
1. Construye la imagen `semaforos-corba:latest` (Python 3.10 + omniorb-py +
   Flask + stubs generados).
2. Levanta **dos contenedores**:
   - `semaforos-servidor` → omniNames + servidor CORBA.
   - `semaforos-web` → Flask (web + cliente CORBA).

La primera vez tarda un poco (descarga e instala todo). Cuando veas en los
logs `TrafficService listo...` y el arranque de Flask, está listo.

---

## 4. Abrir la web

En tu navegador:
```
http://localhost:8080
```
Haz clic en los marcadores: navegador → web (contenedor) → CORBA → servidor
(contenedor) → y de vuelta. **Todo dentro de Docker.**

---

## 5. Comandos útiles

```bash
# Levantar en segundo plano (sin ocupar la terminal)
docker compose up --build -d

# Ver los logs
docker compose logs -f
docker compose logs -f servidor      # solo el servidor
docker compose logs -f web           # solo la web

# Parar y limpiar
docker compose down

# Reconstruir desde cero (si cambiaste codigo)
docker compose up --build --force-recreate
```

---

## 6. (Opcional) Usar el cliente de consola contra los contenedores

El cliente de consola corre dentro de la misma imagen:
```bash
docker compose exec servidor python console_client/console.py \
  -ORBInitRef NameService=corbaname::servidor:2809
```

---

## 🧩 Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Cannot connect to the Docker daemon` | El servicio Docker no está arrancado | `sudo service docker start` |
| `permission denied` al usar docker | Tu usuario no está en el grupo `docker` | `sudo usermod -aG docker $USER` y reabrir terminal |
| La web abre pero no hay datos | El contenedor web no resuelve el servidor | Revisa logs: `docker compose logs servidor` (¿arrancó omniNames?) |
| `TRANSIENT` / `COMM_FAILURE` | El IOR publica un host no resoluble | Confirma que `endPointPublish` usa `servidor` (nombre del servicio) en `docker-compose.yml` |
| El build falla instalando paquetes | Red o caché de apt | Reintenta `docker compose build --no-cache` |

---

## 📦 Qué hay dentro (archivos Docker)

- **`Dockerfile`** — define la imagen: Python 3.10, instala `omniorb-py` y
  Flask, copia el código y genera los stubs desde el IDL.
- **`docker-compose.yml`** — orquesta los dos contenedores (servidor y web) y
  su red interna para que se encuentren por nombre.
- **`docker/entrypoint-server.sh`** — arranque del servidor: lanza omniNames y
  luego el servidor CORBA (fija puerto IIOP y publica el host).
- **`docker/entrypoint-web.sh`** — arranque de la web: Flask resolviendo el
  servidor por el Naming Service.
- **`.dockerignore`** — evita copiar al build lo innecesario (git, venv,
  stubs/IOR generados, etc.).

> Los *entrypoints* viven en scripts aparte (no en comandos dentro del YAML)
> para que los argumentos `-ORB...` lleguen intactos al proceso Python.

---

## ➡️ Siguiente paso: llevarlo a AWS

Una vez que `docker compose up` funciona en local, la **misma imagen** se
despliega en EC2 con `docker run`. Esa guía se añadirá aparte (Fase 2). El
patrón será:

```
docker build  →  (opcional: push a ECR)  →  en cada EC2: docker run
```
con los puertos IIOP (5000), omniNames (2809) y web (8080) expuestos, y
`-ORBendPointPublish` anunciando la **IP pública** de la instancia.
