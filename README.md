# FinFlow — AWS Cloud Resiliency & Scaling Sprint

Solución completa para el Mini-Proyecto (10.0 pts): API Gateway con Nginx,
backend escalado horizontalmente, base de datos aislada, backups
automatizados y despliegue CI/CD sin SSH manual.

## Requisitos previos

- Docker + Docker Compose v2 (`docker compose version` debe mostrar v2.x;
  el CLI v2 es el que respeta `deploy.resources.limits` sin necesitar modo Swarm).
- Un servidor Ubuntu (EC2) con Docker instalado, para el CI/CD.
- Una llave SSH dedicada para GitHub Actions (no la personal de nadie).

## 1. Levantar el entorno

```bash
cp .env.example .env    # define DB_PASSWORD ahí
docker compose up -d --build
```

## 2. Escalamiento horizontal + balanceo (2.5 pts)

```bash
docker compose up -d --scale backend-service=3
```

Validar que Nginx reparte el tráfico alternando el hostname (cada réplica
devuelve un `hostname` distinto, que es el container ID):

```bash
for i in {1..6}; do curl -s http://localhost/ | grep hostname; done
```

Deberías ver 2-3 hostnames distintos rotando. Validar límites de CPU/RAM:

```bash
docker stats
```

## 3. Hardening perimetral (2.5 pts)

El `docker-compose.yml` no tiene `ports:` en el servicio `db`, y `db` vive
en `private-net`, una red marcada `internal: true` (Docker bloquea toda
salida/entrada externa a esa red).

Validar desde el host (debe fallar / timeout, prueba de que el puerto
está cerrado al exterior):

```bash
nc -zv -w 3 localhost 5432   # Connection refused / timed out
```

Validar que sí funciona internamente entre contenedores:

```bash
docker compose exec backend-service ping -c 2 db
```

## 4. SRE — Backups y resiliencia ante caos (2.5 pts)

Generar un respaldo manual:

```bash
./backup_agent.sh
ls -lh backups/
```

Simular una caída catastrófica e inyectar SIGKILL a una réplica:

```bash
docker kill -s SIGKILL $(docker compose ps -q backend-service | head -n1)
```

Con `restart: unless-stopped`, Docker reinicia el contenedor
automáticamente en segundos (RTO < 5s). Verificar:

```bash
docker compose ps
```

Para respaldos automáticos, agrega esto al crontab del servidor:

```bash
crontab -e
# cada 6 horas:
0 */6 * * * /opt/finflow-devops/backup_agent.sh >> /var/log/finflow_backup.log 2>&1
```

## 5. Pipeline CI/CD (2.5 pts)

1. En GitHub → Settings → Secrets and variables → Actions, crea:
   - `SERVER_IP`
   - `SERVER_USER`
   - `SSH_PRIVATE_KEY` (la llave privada completa, formato PEM)
2. En el servidor, agrega la llave pública correspondiente a
   `~/.ssh/authorized_keys` del usuario de despliegue.
3. Clona el repo una vez manualmente en `/opt/finflow-devops` en el
   servidor (el workflow solo hace `git pull`, no clona desde cero).
4. Cualquier `git push` a `main` dispara `.github/workflows/deploy.yml`,
   que se conecta por SSH y ejecuta `git pull` + `docker compose up -d
   --build` automáticamente. Ningún desarrollador toca el servidor por
   SSH manualmente.
5. Verifica la "Luz Verde" (✔) en la pestaña **Actions** del repo.

## Estructura del proyecto

```
finflow-devops/
├── docker-compose.yml
├── nginx/
│   └── nginx.conf
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── backup_agent.sh
├── backups/              # se llena en tiempo de ejecución
└── .github/
    └── workflows/
        └── deploy.yml
```

## ⚠️ Recordatorio de entrega

El PDF final que suba el Líder DevOps debe incluir una **portada con los
nombres completos de todos los integrantes** que participaron en el
sprint, más las capturas de pantalla de cada validación de arriba
(docker stats, curl de balanceo, nc al 5432, docker kill + auto-restart,
ls de backups/, y el check verde en GitHub Actions).
