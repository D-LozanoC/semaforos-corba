# 🚦 Semáforos Inteligentes con CORBA — Bogotá

Mini proyecto didáctico que demuestra cómo funciona el middleware **CORBA**
en un sistema distribuido, usando un ejemplo claro: consultar el tráfico
simulado de intersecciones de Bogotá.

> **Arquitectura elegida: Opción B.** La interfaz web y el cliente CORBA
> viven en el **mismo proceso Flask**, para no tener un intermediario
> innecesario. Un segundo cliente (consola) habla CORBA directo, y así se
> demuestra que **clientes distintos invocan el mismo contrato IDL**.

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

El punto clave: **el navegador no puede hablar CORBA** (CORBA usa IIOP, no
HTTP). Por eso Flask traduce HTTP↔CORBA dentro del mismo proceso. El cliente
de consola, en cambio, sí habla CORBA directo. Ambos usan el **mismo
contrato IDL** (`idl/traffic.idl`) sin conocer la implementación interna del
servidor: eso es la **transparencia** que demuestra CORBA.

---

## 📁 Estructura

```
semaforos-corba/
├── idl/
│   └── traffic.idl           # EL CONTRATO. Todo se genera de aquí.
├── server/
│   ├── server.py             # Servidor CORBA (implementa TrafficService)
│   ├── data.py               # Datos simulados de Bogotá
│   └── (traffic/, traffic__POA/, server.ior)  # generados en runtime
├── common/
│   └── corba_client.py       # Lógica compartida para conectarse al servidor
├── web_client/
│   ├── app.py                # OPCIÓN B: web + cliente CORBA en un proceso
│   └── templates/index.html  # Mapa Leaflet
├── console_client/
│   └── console.py            # Cliente CORBA de consola
├── scripts/
│   ├── gen_stubs.sh          # Genera los stubs desde el IDL (omniidl)
│   ├── run_server.sh
│   ├── run_web.sh
│   └── run_console.sh
├── requirements.txt
└── README.md
```

---

## ⚙️ Instalación

Necesitas **omniORB + omniORBpy** (el ORB y su mapeo a Python) y **Flask**.

### Ubuntu / Debian (recomendado para EC2)
```bash
sudo apt update
sudo apt install -y omniorb omniidl omniorb-nameserver python3-omniorb
pip install Flask
```

### pip (Python ≥ 3.10)
```bash
pip install omniorb-py Flask
```

### conda
```bash
conda install -c conda-forge omniorbpy flask
```

Comprueba que `omniidl` está disponible:
```bash
omniidl -V
```

---

## ▶️ Ejecución en LOCAL (3 terminales)

### 1) Generar los stubs desde el IDL (solo la primera vez)
```bash
bash scripts/gen_stubs.sh
```
Esto ejecuta `omniidl -bpython` y crea los paquetes `traffic/` y
`traffic__POA/` dentro de `server/`.

### 2) Arrancar el servidor CORBA
```bash
bash scripts/run_server.sh
```
El servidor se registra en omniNames (si está disponible) y **siempre**
escribe `server/server.ior` como respaldo. En local no necesitas omniNames:
el IOR por archivo basta.

### 3a) Arrancar la web (Opción B)
```bash
bash scripts/run_web.sh
# abre http://localhost:8080
```

### 3b) O usar el cliente de consola
```bash
bash scripts/run_console.sh            # lista todas las intersecciones
bash scripts/run_console.sh INT-03     # consulta una
```

---

## ☁️ Despliegue en AWS EC2

El **servidor CORBA** y la **web+cliente CORBA (Flask)** van a EC2. Al
fusionar web y cliente en un proceso (Opción B), **ya no necesitas GitHub
Pages** ni te preocupas por CORS ni por "mixed content".

### Puntos críticos (los que normalmente rompen CORBA en la nube)

1. **Fijar el puerto IIOP del servidor** (si no, usa un puerto aleatorio
   imposible de abrir en el firewall):
   ```bash
   python server.py \
     -ORBendPoint giop:tcp::5000 \
     -ORBendPointPublish giop:tcp:<IP_PUBLICA_EC2>:5000
   ```
   `endPointPublish` hace que el IOR anuncie la IP **pública**, no la privada.

2. **Security Group de EC2**: abre los puertos
   - `5000` (IIOP del servidor),
   - `2809` (omniNames, si lo usas),
   - `8080` (Flask), o `80/443` si pones nginx delante.

3. **Naming Service** (opcional pero recomendado entre instancias):
   ```bash
   # en la instancia del servidor
   omniNames -start 2809

   # el cliente/web resuelven con:
   python app.py -ORBInitRef NameService=corbaname::<IP_NAMING>:2809
   ```
   Si prefieres simplicidad, copia el `server.ior` del servidor a la
   instancia de Flask y deja que use el fallback por archivo.

---

## 🎓 ¿Qué demuestra este proyecto sobre CORBA?

- **Contrato IDL independiente del lenguaje** (`traffic.idl`): define *qué*
  se puede invocar, no *cómo* está hecho.
- **Transparencia de ubicación**: los clientes invocan `get_intersection()`
  como si fuera local; el ORB se encarga del transporte por la red (IIOP).
- **Clientes heterogéneos, mismo contrato**: la web (vía Flask) y la consola
  invocan exactamente el mismo `TrafficService`.
- **Stubs y skeletons generados**: `omniidl` genera el código de
  serialización (marshalling) automáticamente desde el IDL.
- **Excepciones de dominio** (`IntersectionNotFound`) que viajan por la red.

Todo esto **sin sensores reales ni algoritmos de tráfico**: los datos se
simulan en `server/data.py`.
