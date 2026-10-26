# ☁️ Despliegue en AWS EC2 — Dos instancias

Guía para desplegar el proyecto en **dos instancias EC2**, demostrando CORBA
distribuido de verdad por la red:

```
┌──────────────────────┐    IIOP (5000) + omniNames (2809)   ┌──────────────────────┐   HTTP (8080)   ┌───────────┐
│  EC2-A               │ ◄─────────────────────────────────► │  EC2-B               │ ◄─────────────► │ Navegador │
│  Servidor CORBA      │                                     │  Flask (web+cliente) │                 │  usuario  │
│  + omniNames         │                                     │                      │                 └───────────┘
└──────────────────────┘                                     └──────────────────────┘
```

> **Sin dominio / sin HTTPS.** El acceso es por `http://<IP_PUBLICA_EC2_B>:8080`.
> Al ser todo HTTP no hay problema de *mixed content*, así que **no** hace falta
> nginx ni certbot. El navegador **nunca** habla CORBA: habla HTTP con Flask, y
> Flask es el cliente CORBA del servidor.

---

## 0. Requisitos de las instancias

- 2 × EC2 con **Ubuntu** (t2.micro/t3.micro bastan para la demo).
- Acceso SSH a ambas.
- Anota de cada instancia su **IP pública** y su **IP privada**
  (las ves en la consola de EC2).

Nombres que usaremos:
- `EC2-A` → servidor CORBA + omniNames.
- `EC2-B` → Flask (web + cliente CORBA).

---

## 1. Preparar AMBAS instancias

Repite esto en **EC2-A y EC2-B** (es el mismo entorno que funciona en local):

```bash
sudo apt update
sudo apt install -y git python3.10 python3.10-venv python3.10-dev omniorb-nameserver

git clone https://github.com/D-LozanoC/semaforos-corba.git
cd semaforos-corba

python3.10 -m venv ~/venv
source ~/venv/bin/activate
pip install --upgrade pip
pip install omniorb-py Flask

# omniidl necesita un 'python' en /usr/local/bin que apunte al venv (3.10)
sudo ln -sf ~/venv/bin/python3 /usr/local/bin/python

bash scripts/gen_stubs.sh
```

> `omniorb-nameserver` (apt) aporta el binario `omniNames`. El binding de
> Python viene de `omniorb-py` (pip). En EC2-B `omniNames` no se usa, pero no
> estorba instalarlo.

---

## 2. Abrir puertos en los Security Groups

En la consola de AWS, edita los *Security Groups*:

| Instancia | Puerto | Protocolo | Origen (Source) | Para qué |
|---|---|---|---|---|
| **EC2-A** | 5000 | TCP | SG o IP de **EC2-B** | IIOP (invocaciones CORBA) |
| **EC2-A** | 2809 | TCP | SG o IP de **EC2-B** | omniNames (servicio de nombres) |
| **EC2-B** | 8080 | TCP | `0.0.0.0/0` (público) | la web, para los usuarios |
| ambas | 22 | TCP | tu IP | SSH |

> 🔒 Buenas prácticas: abre 5000 y 2809 **solo** hacia EC2-B (no al mundo).
> 8080 sí debe estar abierto al público para que la web sea accesible.

---

## 3. Arrancar el SERVIDOR (en EC2-A)

```bash
cd ~/semaforos-corba
export PUBLIC_IP=<IP_PUBLICA_EC2_A>
export PRIVATE_IP=<IP_PRIVADA_EC2_A>
bash deploy/start_server_ec2.sh
```

El script:
1. Arranca `omniNames` en el puerto 2809 (si no está ya).
2. Arranca el servidor CORBA fijando el puerto IIOP (**5000**) y publicando la
   **IP pública** en el IOR (clave para que EC2-B lo alcance).

Debe quedar en `TrafficService listo. Esperando invocaciones...`.

---

## 4. Arrancar la WEB (en EC2-B)

```bash
cd ~/semaforos-corba
export SERVER_IP=<IP_PUBLICA_EC2_A>
bash deploy/start_web_ec2.sh
```

Resuelve `TrafficService` vía el omniNames de EC2-A y levanta Flask en 8080.

---

## 5. Abrir la web

En tu navegador:
```
http://<IP_PUBLICA_EC2_B>:8080
```
Deberías ver el mapa de Bogotá. Cada clic en un marcador viaja:
**navegador → Flask (EC2-B) → CORBA/IIOP → servidor (EC2-A) → y de vuelta.**

---

## 6. (Recomendado) Dejarlo como servicio que no se cae al cerrar SSH

Si cierras la sesión SSH, los procesos lanzados a mano mueren. Para que
sobrevivan, usa los servicios **systemd** incluidos:

**En EC2-A:**
```bash
sudo nano deploy/semaforos-server.service   # edita PUBLIC_IP y PRIVATE_IP
sudo cp deploy/semaforos-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now semaforos-server
journalctl -u semaforos-server -f           # ver logs
```

**En EC2-B:**
```bash
sudo nano deploy/semaforos-web.service       # edita SERVER_IP
sudo cp deploy/semaforos-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now semaforos-web
journalctl -u semaforos-web -f
```

> Los `.service` asumen usuario `ubuntu` y el proyecto en
> `/home/ubuntu/semaforos-corba`. Ajusta `User=` y `WorkingDirectory=` si usas
> otra ruta/usuario.

---

## 7. Comprobar que el cliente de consola también funciona (opcional)

Para reforzar la demostración de "clientes heterogéneos, mismo contrato",
desde **EC2-B** (o tu máquina, si abres el puerto) puedes usar la consola:
```bash
source ~/venv/bin/activate
export PYTHONPATH="$HOME/semaforos-corba/server:$HOME/semaforos-corba/common"
cd ~/semaforos-corba/console_client
python console.py -ORBInitRef NameService=corbaname::<IP_PUBLICA_EC2_A>:2809
```

---

## 🧩 Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| La web carga pero los datos no llegan | EC2-B no alcanza el IIOP de EC2-A | Revisa que el puerto **5000** esté abierto en el SG de EC2-A hacia EC2-B |
| `TRANSIENT` / `COMM_FAILURE` en Flask | El IOR publica una IP inalcanzable | Confirma `PUBLIC_IP` correcta en EC2-A (va en `-ORBendPointPublish`) |
| `InitialRefNotFound` / no resuelve el nombre | omniNames no accesible | Abre el **2809** en EC2-A; verifica que omniNames esté corriendo |
| La web no abre desde el navegador | Puerto 8080 cerrado | Abre **8080** a `0.0.0.0/0` en el SG de EC2-B |
| Todo muere al cerrar SSH | Procesos en primer plano | Usa los servicios systemd (paso 6) |

---

## 💡 ¿Por qué esta arquitectura demuestra bien CORBA?

- El **servidor** (EC2-A) y el **cliente** (Flask en EC2-B) están en **máquinas
  distintas** y se comunican por **IIOP** sobre la red real.
- El cliente invoca `get_intersection()` como si fuera local: el **ORB** se
  encarga del transporte. Eso es la **transparencia de ubicación** de CORBA.
- El **contrato IDL** (`traffic.idl`) es lo único compartido; ninguno conoce la
  implementación interna del otro.
