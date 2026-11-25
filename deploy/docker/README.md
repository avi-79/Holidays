# Holidays Docker deployment (Windows and Linux)

The same Docker images and Compose stack work on Windows and Linux. The containers use the Linux-based Node.js and PostgreSQL images, so the application runtime is consistent across both host operating systems.

## Requirements

- **Windows:** Docker Desktop with the WSL 2 backend enabled and the Docker engine running. Use PowerShell 5.1 or PowerShell 7.
- **Linux:** Docker Engine and the Docker Compose v2 plugin installed and running.
- Git, to clone or update this repository.

Check the installation:

```text
docker --version
docker compose version
docker info
```

Use `docker compose` (Compose v2), not the obsolete `docker-compose` standalone command.

## Windows PowerShell

Open PowerShell in the cloned Holidays folder:

```powershell
cd C:\path\to\Holidays
git pull --ff-only origin main
.\deploy\docker\holidays-docker.ps1
```

The script checks Docker Desktop and Compose, creates `.env.docker` with unique random secrets on first run, and builds and starts the application.

Useful commands:

```powershell
.\deploy\docker\holidays-docker.ps1 config --quiet
.\deploy\docker\holidays-docker.ps1 build
.\deploy\docker\holidays-docker.ps1 up -d
.\deploy\docker\holidays-docker.ps1 ps
.\deploy\docker\holidays-docker.ps1 logs -f
.\deploy\docker\holidays-docker.ps1 logs -f api-gateway
.\deploy\docker\holidays-docker.ps1 down
```

If PowerShell blocks the script because of the current process execution policy, run this for the current PowerShell window only, then rerun the script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Linux (Amazon Linux 2023, Ubuntu, etc.)

From the repository folder:

```bash
git pull --ff-only origin main
chmod +x deploy/docker/holidays-docker.sh
./deploy/docker/holidays-docker.sh
```

Useful commands:

```bash
./deploy/docker/holidays-docker.sh config --quiet
./deploy/docker/holidays-docker.sh build
./deploy/docker/holidays-docker.sh up -d
./deploy/docker/holidays-docker.sh ps
./deploy/docker/holidays-docker.sh logs -f
./deploy/docker/holidays-docker.sh logs -f api-gateway
./deploy/docker/holidays-docker.sh down
```

The Linux helper requires `openssl` to generate secrets.

## Manual commands (same on Windows and Linux)

If you prefer not to use the helper scripts, create `.env.docker` from `.env.docker.example`, replace every placeholder with a different random secret, then run:

```bash
docker compose --env-file .env.docker config --quiet
docker compose --env-file .env.docker build
docker compose --env-file .env.docker up -d
docker compose --env-file .env.docker ps
```

PowerShell does not support the Bash `source` command. Do not use `source .env.docker` in PowerShell; Docker Compose reads the file directly with `--env-file`.

## Open and verify the application

Open **http://localhost:8080** on the same computer running Docker.

```bash
docker compose --env-file .env.docker ps
curl http://localhost:8080/api/health
```

On Windows, you can also open the URL in a browser. Only the API Gateway is published to the host on port 8080. PostgreSQL and the internal microservices are reachable only inside the Compose network.

For EC2, allow inbound TCP 8080 only from your own IP for a temporary test. Do not expose ports 8081, 8082, 8083, or 5432 publicly.

## Services and interview mapping

| Container | Responsibility | Internal port |
|---|---|---:|
| api-gateway | Frontend, authentication and API routing | 8080 |
| accommodation-service | Stay catalogue and inventory | 8081 |
| booking-service | Booking creation, lookup and cancellation | 8082 |
| payment-service | Demo payment simulation | 8083 |
| postgres | Four service-specific databases | 5432 |

Compose creates a bridge network and service DNS names. For example, the gateway calls `http://accommodation-service:8081`, not `localhost:8081`. The named volume `holidays-postgres-data` persists database data across container recreation.

## Troubleshooting

```bash
docker compose --env-file .env.docker ps -a
docker compose --env-file .env.docker logs --tail=100
docker compose --env-file .env.docker logs --tail=100 postgres
docker compose --env-file .env.docker logs --tail=100 api-gateway
docker compose --env-file .env.docker config --quiet
docker network ls
docker volume ls
```

- If `docker compose` is not recognised, update/start Docker Desktop on Windows or install the Docker Compose v2 plugin on Linux.
- If Docker cannot connect to its engine, start Docker Desktop or the Linux Docker service.
- If port 8080 is already in use, stop the process using it or change the host side of the Compose mapping from `8080:8080`.
- If a database password was changed after the PostgreSQL volume was initialized, the existing database role password is not automatically changed. Resolve the database credentials deliberately; do not delete the volume just to hide the error.
- Do not run `down -v` unless you intentionally want to delete the local PostgreSQL data.

## Secrets and data

- The helper scripts create `.env.docker` locally only if it does not already exist.
- Never commit or share `.env.docker`. The repository ignores it.
- Keep a secure backup of any data you need. The PostgreSQL named volume is local to the Docker host and is not automatically shared between your Windows computer and EC2.
- The PostgreSQL initialization script runs only when the data directory is first initialized.
- The payment service is a demo simulation only. It does not charge money or process real card details.
