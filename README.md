# Holidays

A responsive, TUI-inspired stay discovery and booking demo. Developed by Avinesh.

## Cross-platform deployment

Holidays is maintained as one codebase for Windows and Linux. The recommended portable deployment is Docker Compose:

- **Windows:** Docker Desktop (WSL 2 backend) + PowerShell.
- **Linux:** Docker Engine + Docker Compose v2.
- Both platforms build and run the same Dockerfiles, services and PostgreSQL image.

See **[Docker deployment for Windows and Linux](deploy/docker/README.md)** for OS-specific commands. The helper scripts create a private `.env.docker` file with local secrets on first run. Never commit that file.

Quick start on Windows PowerShell:

```powershell
git clone https://github.com/avi-79/Holidays.git
cd Holidays
.\deploy\docker\holidays-docker.ps1
```

Quick start on Linux:

```bash
git clone https://github.com/avi-79/Holidays.git
cd Holidays
chmod +x deploy/docker/holidays-docker.sh
./deploy/docker/holidays-docker.sh
```

Open http://localhost:8080 after the containers become healthy.

## Application architecture

| Component | Port | Responsibility |
|---|---:|---|
| React frontend + API Gateway | 8080 | Browser entry point, authentication and API routing |
| Accommodation Service | 8081 | Stay catalogue and inventory |
| Booking Service | 8082 | Create, view and cancel bookings |
| Payment Service (demo) | 8083 | Simulated payment record and booking confirmation |
| PostgreSQL | 5432 | Four separate databases, one per service |

Only the API Gateway is published to the host by Docker Compose. Internal services and PostgreSQL communicate over the private Compose network using service DNS names.

## Local Node.js development

Requires Node.js 20+ and PostgreSQL. Install dependencies with `npm install`, configure the database URLs and secrets from `deploy/microservices.env.example`, then start each backend in a separate terminal:

```text
npm run dev:accommodation
npm run dev:booking
npm run dev:payment
npm run dev:gateway
npm run dev
```

Open http://localhost:5173. Vite proxies API requests to the local API Gateway on port 8080. Set the environment variables in the terminal/session before starting the services; the exact environment-variable syntax differs between PowerShell and Bash. Docker Compose avoids that shell-specific setup.

## Amazon Linux 2023 deployment without Docker

The separate systemd/Nginx deployment remains available for the existing EC2 learning path. See **[deploy/README.md](deploy/README.md)**. This is a Linux-specific host deployment; use Docker Compose for the same containerized workflow on Windows and Linux.

The previous SQLite users/bookings database is not automatically migrated to PostgreSQL. Back it up and plan a deliberate migration before switching an existing instance.

## Security and demo-data notice

- Configure HTTPS before using real account credentials.
- Never expose PostgreSQL port 5432 or internal service ports 8081–8083 publicly.
- Stay catalogue, prices and availability are sample data, not live hotel inventory.
- The payment page is a demo flow. It does not collect real card/bank credentials and does not charge money.

Holidays · Developed by Avinesh
