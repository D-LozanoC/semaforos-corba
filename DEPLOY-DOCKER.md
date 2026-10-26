# 🐳☁️ Despliegue en AWS EC2 con Docker — paso a paso

Despliegue del proyecto en **dos instancias EC2** usando Docker, de la forma
más simple: la imagen se **construye en cada instancia** (sin ECR).

```
┌──────────────────────┐   IIOP 5000 + omniNames 2809   ┌──────────────────────┐   HTTP 8080   ┌───────────┐
│ EC2-A (servidor)     │ ◄────────────────────────────► │ EC2-B (web)          │ ◄───────────► │ Navegador │
│ docker: servidor     │                                │ docker: web          │               └───────────┘
└──────────────────────┘                                └──────────────────────┘
```

---

## FASE 1 — Crear las instancias

### 1.1 Security Group (una vez)
AWS → **EC2 → Security Groups → Create security group** → nombre `semaforos-sg`.
Reglas de entrada (*inbound*):

| Tipo | Puerto | Origen | Para qué |
|---|---|---|---|
| SSH | 22 | My IP | acceso SSH |
| Custom TCP | 8080 | 0.0.0.0/0 | la web (público) |
| Custom TCP | 5000 | 0.0.0.0/0 | IIOP CORBA |
| Custom TCP | 2809 | 0.0.0.0/0 | omniNames |

### 1.2 Lanzar 2 instancias
**EC2 → Launch instances**:
- Number of instances: **2**
- AMI: **Ubuntu Server 24.04 LTS**
- Tipo: **t2.micro** (free tier)
- Key pair: crea `semaforos-key` y **descarga el `.pem`**
- Security group: **selecciona `semaforos-sg`**

### 1.3 Anotar IPs
Decide cuál es **EC2-A (servidor)** y **EC2-B (web)**. Anota:
- EC2-A → **IP pública** y **IP privada**
- EC2-B → **IP pública**

---

## FASE 2 — Conectarse por SSH e instalar Docker (en AMBAS)

Desde tu máquina (ajusta la ruta del `.pem` y la IP):
```bash
chmod 400 semaforos-key.pem
ssh -i semaforos-key.pem ubuntu@<IP_PUBLICA_DE_LA_INSTANCIA>
```

Ya dentro de cada instancia:
```bash
sudo apt update
sudo apt install -y docker.io git
sudo usermod -aG docker $USER
newgrp docker          # aplica el grupo sin reconectar
docker --version       # verifica
```

---

## FASE 3 — Clonar y construir la imagen (en AMBAS)

```bash
git clone https://github.com/D-LozanoC/semaforos-corba.git
cd semaforos-corba
docker build -t semaforos-corba:latest .
```
> La primera build tarda unos minutos (descarga Python, instala omniorb-py,
> genera los stubs). Es normal.

---

## FASE 4 — Arrancar los contenedores

### En EC2-A (servidor) — usa SU PROPIA IP pública
```bash
docker run -d --name servidor --restart unless-stopped \
  -p 5000:5000 -p 2809:2809 \
  -e PUBLISH_HOST=<IP_PUBLICA_EC2_A> \
  -e IIOP_PORT=5000 -e NS_PORT=2809 \
  semaforos-corba:latest \
  sh /app/docker/entrypoint-server.sh
```
Verifica:
```bash
docker logs -f servidor
# debe mostrar: "Registrado en omniNames" y "TrafficService listo..."
```

### En EC2-B (web) — apunta a la IP pública de EC2-A
```bash
docker run -d --name web --restart unless-stopped \
  -p 8080:8080 \
  -e SERVER_HOST=<IP_PUBLICA_EC2_A> \
  -e NS_PORT=2809 -e WEB_PORT=8080 \
  semaforos-corba:latest \
  sh /app/docker/entrypoint-web.sh
```
Verifica:
```bash
docker logs -f web
# debe mostrar: "Conectado via omniNames" y "Running on ... 0.0.0.0:8080"
```

---

## FASE 5 — Abrir la web

En tu navegador:
```
http://<IP_PUBLICA_EC2_B>:8080
```
Cada clic viaja: navegador → web (EC2-B) → IIOP/CORBA → servidor (EC2-A) → vuelta.

---

## Comandos útiles (en cada EC2)

```bash
docker ps                     # contenedores corriendo
docker logs -f servidor       # logs del servidor (EC2-A)
docker logs -f web            # logs de la web (EC2-B)
docker restart servidor       # reiniciar
docker stop servidor && docker rm servidor   # parar y borrar

# Tras un 'git pull' con cambios, reconstruir:
docker build -t semaforos-corba:latest .
docker stop web && docker rm web   # y volver a 'docker run ...'
```

---

## 🧩 Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| La web carga pero sin datos | EC2-B no alcanza a EC2-A | Revisa que 5000 y 2809 estén abiertos en el SG |
| `web` reintenta y nunca conecta | `SERVER_HOST` mal o servidor caído | Confirma la IP pública de EC2-A; mira `docker logs servidor` |
| `COMM_FAILURE` / `TRANSIENT` | El IOR publica un host no alcanzable | Confirma `PUBLISH_HOST=<IP_PUBLICA_EC2_A>` (la pública, no la privada) |
| La web no abre en el navegador | Puerto 8080 cerrado | Abre 8080 a 0.0.0.0/0 en el SG de EC2-B |
| `permission denied` con docker | Falta el grupo docker | `sudo usermod -aG docker $USER && newgrp docker` |

---

## 💡 Diferencia con el modo local (docker-compose)

- En **local**, los contenedores se encuentran por el nombre DNS de Docker
  (`servidor`), gestionado por `docker-compose.yml`.
- En **EC2**, están en máquinas distintas: se usan las **IPs públicas** reales
  (`PUBLISH_HOST` y `SERVER_HOST`) y hay que abrir los puertos en el Security
  Group. El resto (la imagen, los entrypoints) es idéntico.
