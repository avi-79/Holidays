# Holidays

A responsive, TUI-inspired stay discovery and booking demo. Developed by Avinesh.

## Current architecture

The current deployment target is a no-Docker Node.js microservices application backed by PostgreSQL.

| Component | Port | Responsibility |
|---|---:|---|
| React frontend + API Gateway | 8080 | Single browser entry point, authentication and API routing |
| Accommodation Service | 8081 | Stay catalogue and date-based inventory |
| Booking Service | 8082 | Create, view and cancel bookings |
| Payment Service (demo) | 8083 | Simulated payment record and booking confirmation |
| PostgreSQL | 5432 | Four separate databases, one per service |
| Nginx | 80 / 443 | Public reverse proxy; configure HTTPS |

The Node.js services bind to loopback. Do not expose ports 8080–8083 or PostgreSQL 5432 publicly.

**Payment notice:** the payment page is a demo flow. It does not collect real card/bank credentials and does not charge money. Stay catalogue, prices and availability are sample data, not live hotel inventory.

## Deploy on Amazon Linux 2023 (without Docker)

Use the dedicated deployment guide:

**[deploy/README.md](deploy/README.md)**

The deployment files are in `deploy/`. The current script is:

```bash
sudo bash deploy/ec2-deploy-microservices.sh
```

The deployment expects Node.js 20+, npm, PostgreSQL and Nginx to be installed and PostgreSQL initialized. Configure the four database roles/passwords and `/etc/holidays/microservices.env` as explained in the deployment guide before running the script.

The old SQLite deployment script is retained as a historical reference and intentionally exits without deploying. The previous SQLite users/bookings database is **not automatically migrated** to PostgreSQL. Back it up and plan a deliberate migration before switching an existing instance.

## Local development

Requires Node.js 20+ and PostgreSQL. Create the four databases using `deploy/postgres/01-create-databases.sql`, then configure the variables from `deploy/microservices.env.example` in your shell. Never commit real passwords or secrets.

Install dependencies:

```bash
npm install
```

Start each backend in a separate terminal:

```bash
npm run dev:accommodation
npm run dev:booking
npm run dev:payment
npm run dev:gateway
```

Start the frontend in another terminal:

```bash
npm run dev
```

Open http://localhost:5173. Vite proxies API calls to the local API Gateway.

## Security

- Configure HTTPS before using real account credentials.
- Set `COOKIE_SECURE=true` after HTTPS is active.
- Keep `/etc/holidays/microservices.env` private (root-owned, mode 0640).
- Use unique strong database passwords, a JWT secret and a separate internal service token.
- Do not expose service ports or PostgreSQL directly to the internet.

Holidays · Developed by Avinesh
