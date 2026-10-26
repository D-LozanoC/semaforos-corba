# 🚦 Semáforos Inteligentes con CORBA — Bogotá

Mini proyecto **didáctico** que muestra, con un ejemplo pequeño y claro, cómo
funciona el middleware **CORBA** en un sistema distribuido. La "excusa" es un
sistema de **semáforos inteligentes**: un mapa de Bogotá con varias
intersecciones; al hacer clic en una, se consulta su tráfico simulado
(cantidad de vehículos, nivel de congestión y espera promedio).

No hay sensores reales ni algoritmos de tráfico: los datos se **simulan** en
el servidor. El objetivo es enseñar **invocación remota** y **comunicación
entre componentes distribuidos** mediante un contrato **IDL**.

> ### ¿Qué demuestra exactamente?
> Que **clientes distintos** (una web y una consola) pueden invocar
> operaciones de un **servidor remoto** usando un contrato definido en **IDL**,
> **sin saber cómo está implementado por dentro**. Eso es la *transparencia*
> que aporta CORBA.

> ### Arquitectura elegida: **Opción B**
> La **interfaz web** y el **cliente CORBA** viven en el **mismo proceso
> Flask**, para no tener un intermediario innecesario. Así evitamos además dos
> dolores de cabeza clásicos: **CORS** y el **"mixed content" HTTPS**. Un
> segundo cliente —el de **consola**— habla CORBA directo, y es el que deja ver
> que *el mismo contrato IDL sirve a clientes totalmente distintos*.

---

## 🧭 Arquitectura

```
                 ┌──────────── MISMO PROCESO PYTHON ────────────┐
  Navegador      │  Flask                                        │        IIOP / GIOP     ┌──────────────────┐
 (Leaflet/JS) ──►│  · sirve el HTML del mapa (Jinja2)            │ ─────────────────────► │  Servidor CORBA  │
              ◄──│  · ES cliente CORBA (omniORBpy) en /api/...   │ ◄───────────────────── │  (omniORBpy)     │
                 └───────────────────────────────────────────────┘                        │  TrafficService  │
                                                                                           └──────────────────┘
                                                                                                    ▲
  Cliente de consola (Python)  ───────────────── IIOP / GIOP ───────────────────────────────────────┘
  (habla CORBA directo, sin HTTP)
```

El punto clave: **el navegador no puede hablar CORBA** (CORBA viaja por
**IIOP** sobre TCP, no por HTTP). Por eso Flask traduce **HTTP ↔ CORBA**
dentro del mismo proceso. El cliente de consola, en cambio, habla CORBA
directo. Ambos usan el **mismo contrato IDL** (`idl/traffic.idl`) sin conocer
la implementación interna del servidor.

### El flujo de una consulta, paso a paso

1. En el navegador haces clic en una intersección del mapa Leaflet.
2. El JavaScript llama a `GET /api/intersections/<id>` (HTTP) de **tu propio Flask**.
3. Flask, que **también es cliente CORBA**, invoca `get_intersection(id)` en el servidor remoto vía IIOP.
4. El servidor ejecuta la lógica (datos simulados) y devuelve una `struct` definida en el IDL.
5. Flask convierte esa `struct` a JSON y la responde al navegador, que pinta el resultado.

---

## 📁 Estructura del proyecto

```
semaforos-corba/
├── idl/
│   └── traffic.idl           # EL CONTRATO. Todo lo demás se genera de aquí.
├── server/
│   ├── server.py             # Servidor CORBA (implementa TrafficService)
│   ├── data.py               # Datos simulados de 8 intersecciones de Bogotá
│   └── (traffic/, traffic__POA/, server.ior)  # ⚙️ GENERADOS en runtime (no se versionan)
├── common/
│   └── corba_client.py       # Lógica compartida para conectarse al servidor
├── web_client/
│   ├── app.py                # OPCIÓN B: web + cliente CORBA en un solo proceso
│   └── templates/index.html  # Mapa interactivo con Leaflet
├── console_client/
│   └── console.py            # Cliente CORBA de consola
├── scripts/
│   ├── gen_stubs.sh / .bat   # Genera los stubs desde el IDL (omniidl)
│   ├── run_server.sh / .bat  # Arranca el servidor
│   ├── run_web.sh / .bat     # Arranca la web + cliente CORBA
│   └── run_console.sh / .bat # Ejecuta el cliente de consola  (.sh = Linux/macOS, .bat = Windows)
├── requirements.txt
└── README.md
```

> Las carpetas `server/traffic/`, `server/traffic__POA/` y el archivo
> `server/server.ior` **se generan** al compilar el IDL y al arrancar el
> servidor; por eso están en `.gitignore` y **no** aparecen en el repo.

---

## ✅ Requisitos previos

| Componente | Para qué | Cómo se obtiene |
|---|---|---|
| **Python 3** (3.10+ recomendado) | Ejecutar todo el proyecto | Ya instalado en Linux/macOS, o [python.org](https://www.python.org) |
| **omniORB** + **omniORBpy** | El ORB de CORBA y su mapeo a Python (incluye `omniidl`) | `apt` / `pip` / `conda` (abajo) |
| **omniNames** *(opcional en local)* | Servicio de nombres CORBA | Viene con omniORB (`omniorb-nameserver`) |
| **Flask** | Servir la web y exponer la API | `pip install Flask` |

Herramientas que proporciona omniORB y que usaremos:
- **`omniidl`** → el compilador de IDL. Genera los *stubs* (cliente) y
  *skeletons* (servidor) en Python a partir de `traffic.idl`.
- **`omniNames`** → el servicio de nombres (lo usaremos sobre todo en EC2).

---

## ⚙️ Instalación

Elige **una** de las vías. En Linux, la de `apt` es la más robusta porque
instala `omniidl` y `omniNames` como comandos del sistema.

### Opción 1 — Ubuntu / Debian (recomendada) 🐧
```bash
sudo apt update
sudo apt install -y omniorb omniidl omniorb-nameserver python3-omniorb
pip install Flask
```

### Opción 2 — pip (requiere **Python ≥ 3.10**) 🐍
```bash
pip install omniorb-py Flask
```
> ⚠️ El paquete de PyPI `omniorb-py` es un *fork* no oficial y exige Python
> 3.10 o superior. Si falla la compilación, usa la vía `apt` (Linux) o
> `conda`.

### Opción 3 — conda (multiplataforma, aísla el entorno) 📦
```bash
conda create -n semaforos python=3.11
conda activate semaforos
conda install -c conda-forge omniorbpy flask
```

### Comprobar que quedó bien instalado
```bash
omniidl -V          # debe imprimir la versión del compilador IDL
python -c "import omniORB, CORBA, CosNaming; print('omniORBpy OK')"
python -c "import flask; print('Flask', flask.__version__)"
```
Si los tres comandos funcionan, estás listo. Si `omniidl` "no se encuentra"
pero instalaste por pip, usa la vía `apt`/`conda`: el compilador viene con el
paquete del sistema.

---

## 🪟 Instalación en Windows

En Windows **no existe `apt`**, y compilar omniORB desde fuente es engorroso
(necesita Visual Studio y configurar variables de entorno). Por eso la vía
recomendada es **conda**, que tiene paquetes precompilados oficiales de
`omniorb` y `omniorbpy` para Windows (`win-64`) en *conda-forge*.

### 🟢 Camino A (recomendado): Miniconda + conda-forge

1. **Instala Miniconda** desde
   [docs.conda.io/projects/miniconda](https://docs.conda.io/projects/miniconda/en/latest/)
   (acepta las opciones por defecto).
2. Abre **"Anaconda Prompt"** desde el menú Inicio (no uses PowerShell/CMD
   normal la primera vez, para que `conda` esté en el PATH).
3. Crea el entorno e instala todo:
   ```bat
   conda create -n semaforos python=3.11
   conda activate semaforos
   conda install -c conda-forge omniorbpy flask
   ```
   > `omniorbpy` arrastra `omniorb` (el ORB base) e incluye `omniidl` y
   > `omniNames` dentro del entorno. Sirven Python 3.11, 3.12 y 3.13.
4. Comprueba la instalación (con el entorno `semaforos` activado):
   ```bat
   omniidl -V
   python -c "import omniORB, CORBA, CosNaming; print('omniORBpy OK')"
   python -c "import flask; print('Flask', flask.__version__)"
   ```

### 🟡 Camino B (alternativa): instalador oficial de omniORB + pip

Si no quieres conda, el autor publica binarios de Windows en
[omniorb.net](https://omniorb.net):

1. Instala **Python** desde [python.org](https://www.python.org/downloads/windows/)
   (marca *"Add python.exe to PATH"*).
2. Descarga el binario de **omniORB + omniORBpy para Windows (x64)** que
   coincida con tu versión de Python.
3. Descomprímelo (p. ej. `C:\omniORB`) y añade a las variables de entorno:
   - `PATH` → `C:\omniORB\bin\x86_win32`
   - `PYTHONPATH` → `C:\omniORB\lib\python`
4. `pip install Flask`

> ⚠️ Esta vía es más frágil: la versión de omniORBpy debe coincidir con la
> versión y arquitectura (x64) exactas de tu Python. Por eso se recomienda conda.

### ▶️ Ejecutar en Windows

Los scripts `.sh` **no corren** en CMD/PowerShell; para Windows usa los
**`.bat`** equivalentes (en Anaconda Prompt, con `semaforos` activado y desde
la raíz del proyecto):

```bat
REM 1) Generar los stubs desde el IDL (solo la primera vez)
scripts\gen_stubs.bat

REM 2) Arrancar el servidor CORBA (Terminal 1 — se queda corriendo)
scripts\run_server.bat

REM 3a) En otra Anaconda Prompt: la web (Terminal 2)
scripts\run_web.bat
REM abre http://localhost:8080

REM 3b) ...o el cliente de consola
scripts\run_console.bat            REM lista todas
scripts\run_console.bat INT-03     REM consulta una
```

> 💡 Alternativa: si usas **Git Bash** o **WSL**, los scripts `bash
> scripts/*.sh` funcionan igual que en Linux.

---

## 🐧 Windows vía WSL (receta probada en Ubuntu)

Si en Windows prefieres WSL (o conda te da problemas con el módulo nativo
`_omnipy`/`_omniidl`), esta es una receta **verificada**. La clave: el paquete
pip `omniorb-py` **solo trae wheel para Python 3.10**, así que el venv debe ser
de esa versión.

```bash
# 1. Requisitos (dentro de Ubuntu/WSL)
sudo apt update
sudo apt install -y git python3.10 python3.10-venv python3.10-dev

# 2. Clonar EN el home de Linux (no en /mnt/c, por los finales de linea CRLF)
cd ~
git clone https://github.com/D-LozanoC/semaforos-corba.git
cd ~/semaforos-corba

# 3. venv con Python 3.10 + binding por pip
python3.10 -m venv ~/semaforos-venv
source ~/semaforos-venv/bin/activate
pip install --upgrade pip
pip install omniorb-py Flask

# 4. omniidl necesita un 'python' en /usr/local/bin que apunte al venv (3.10)
sudo ln -sf ~/semaforos-venv/bin/python3 /usr/local/bin/python

# 5. Verificar
python -c "import omniORB, flask; print('binding OK')"
python -c "import _omniidl; print('omniidl OK')"
```

A partir de aquí, cada terminal nueva necesita `source ~/semaforos-venv/bin/activate`
antes de ejecutar los scripts. (El `gen_stubs.sh` detecta el venv y lanza
omniidl con el Python correcto automáticamente.)

---

## ▶️ Ejecución en LOCAL — paso a paso

> Los comandos de esta sección usan los scripts `.sh` (**Linux/macOS**). En
> **Windows**, sustituye cada `bash scripts/xxx.sh` por `scripts\xxx.bat`
> (ver la sección [Instalación en Windows](#-instalación-en-windows)).

En local **no necesitas omniNames**: el servidor escribe su referencia en un
archivo `server/server.ior` y los clientes lo leen desde ahí automáticamente.
Esa es la forma más simple de empezar.

> 💡 Vas a necesitar **2 terminales** abiertas en la raíz del proyecto: una
> para el servidor (se queda corriendo) y otra para el cliente (web o consola).

### Paso 0 — Clonar el repositorio
```bash
git clone https://github.com/D-LozanoC/semaforos-corba.git
cd semaforos-corba
```

### Paso 1 — Generar los stubs desde el IDL  *(solo la primera vez)*
```bash
bash scripts/gen_stubs.sh
```
Internamente ejecuta `omniidl -bpython -C. ../idl/traffic.idl`, que **lee el
contrato** y crea dentro de `server/`:
- el paquete **`traffic/`** (los *stubs*: lo que invocan los clientes),
- el paquete **`traffic__POA/`** (los *skeletons*: la base del servidor),
- un módulo `traffic_idl.py`.

> Repite este paso solo si cambias `idl/traffic.idl`.

### Paso 2 — Arrancar el servidor CORBA  *(Terminal 1)*
```bash
bash scripts/run_server.sh
```
Deberías ver algo como:
```
[servidor] IOR escrito en .../server/server.ior
[servidor] TrafficService listo. Esperando invocaciones...
[servidor] (Ctrl+C para salir)
```
Déjalo corriendo. (Verás un aviso de que omniNames no está disponible: es
**normal** en local; el servidor usa el archivo IOR como respaldo.)

### Paso 3a — Arrancar la web  *(Terminal 2)* — Opción B
```bash
bash scripts/run_web.sh
```
Abre **http://localhost:8080** en el navegador. Haz clic en los marcadores del
mapa para consultar el tráfico. Cada clic viaja: navegador → Flask → CORBA →
servidor → y de vuelta.

### Paso 3b — O probar el cliente de consola  *(Terminal 2)*
```bash
bash scripts/run_console.sh            # lista TODAS las intersecciones
bash scripts/run_console.sh INT-03     # consulta UNA intersección
```
Salida de ejemplo:
```
============================================================
Consulta de interseccion: INT-03
============================================================
  INT-03  |  Av. Boyaca con Calle 80
     vehiculos: 47    congestion: MEDIO   espera: 38s
     coords: (4.6945, -74.1030)
```

### Verificación rápida (que todo funciona)
- ✅ El servidor imprime `TrafficService listo...` y **no** se cierra.
- ✅ `run_console.sh` lista las 8 intersecciones con números distintos cada vez (los datos son aleatorios).
- ✅ La web en `:8080` muestra el mapa con marcadores de colores (verde/naranja/rojo según congestión).

---

## 🧩 Solución de problemas (local)

| Síntoma | Causa probable | Solución |
|---|---|---|
| `omniidl: command not found` | omniORB se instaló solo por pip, sin el compilador del sistema | Instala por `apt` (`sudo apt install omniidl`) o por `conda` |
| `ModuleNotFoundError: No module named 'traffic'` | No generaste los stubs | Ejecuta `bash scripts/gen_stubs.sh` |
| `ImportError: No module named 'omniORB'` | omniORBpy no instalado o entorno equivocado | Revisa la instalación y que uses el mismo intérprete (`python -c "import omniORB"`) |
| `No se pudo localizar TrafficService` en el cliente | El servidor no está corriendo o no hay `server.ior` | Arranca primero el servidor (Paso 2); confirma que existe `server/server.ior` |
| El puerto 8080 está ocupado | Otro proceso lo usa | Cambia el puerto en `web_client/app.py` (`app.run(port=...)`) |
| `ModuleNotFoundError: No module named 'flask'` | Flask no instalado en este intérprete | `pip install Flask` |
| **(Windows)** `'bash' no se reconoce...` | Estás usando los scripts `.sh` en CMD/PowerShell | Usa los scripts `.bat` (`scripts\run_server.bat`), o Git Bash/WSL |
| **(Windows)** `'omniidl' no se reconoce...` | El entorno conda no está activado o conda no está en el PATH | Abre **Anaconda Prompt** y ejecuta `conda activate semaforos` |

---

## ☁️ Despliegue en AWS EC2

El **servidor CORBA** y la **web + cliente CORBA (Flask)** van a EC2. Al
fusionar web y cliente en un proceso (Opción B), **no necesitas GitHub Pages**
ni te preocupas por CORS ni por "mixed content".

### Puntos críticos (los que normalmente rompen CORBA en la nube)

1. **Fijar el puerto IIOP del servidor** (si no, usa un puerto aleatorio
   imposible de abrir en el firewall):
   ```bash
   python server.py \
     -ORBendPoint giop:tcp::5000 \
     -ORBendPointPublish giop:tcp:<IP_PUBLICA_EC2>:5000
   ```
   `-ORBendPointPublish` hace que el IOR anuncie la IP **pública** (la que ven
   los clientes), no la privada de la instancia.

2. **Security Group de EC2**: abre los puertos
   - `5000` (IIOP del servidor),
   - `2809` (omniNames, si lo usas),
   - `8080` (Flask), o `80`/`443` si pones nginx delante.

3. **Naming Service** (recomendado entre instancias). omniNames arranca la
   primera vez con `-start` y escucha en **2809** por defecto:
   ```bash
   # en la instancia del servidor (primera vez)
   omniNames -start 2809

   # el servidor / la web / la consola resuelven el nombre con:
   python app.py -ORBInitRef NameService=corbaname::<IP_NAMING>:2809
   ```
   Alternativa simple: copia el `server/server.ior` del servidor a la
   instancia de Flask y deja que use el **fallback por archivo** (sin omniNames).

---

## 🎓 Conceptos de CORBA que ilustra el proyecto

- **Contrato IDL independiente del lenguaje** (`traffic.idl`): define *qué* se
  puede invocar, no *cómo* está hecho.
- **Transparencia de ubicación**: los clientes invocan `get_intersection()`
  como si fuera una llamada local; el ORB se encarga del transporte por red (IIOP).
- **Clientes heterogéneos, mismo contrato**: la web (vía Flask) y la consola
  invocan exactamente el mismo `TrafficService`.
- **Stubs y skeletons generados**: `omniidl` genera automáticamente el código
  de serialización (*marshalling*) a partir del IDL.
- **Excepciones de dominio** (`IntersectionNotFound`) que viajan por la red
  igual que cualquier otro tipo del IDL.

Todo esto **sin sensores reales ni algoritmos de tráfico**: los datos se
simulan en `server/data.py`.
