# Holidays

A responsive, TUI-inspired stay discovery and booking-request demo. Developed by Avinesh.

## Features

- Responsive stay discovery, destination search, category filters, sorting and favourites
- Account registration, login and logout
- Password hashes stored with bcrypt; signed sessions use HttpOnly cookies
- SQLite persistence for users and booking requests
- Authenticated users can access only their own booking requests
- Rate-limited authentication endpoints and server-side input validation
- Express API health endpoint for deployment checks

> **Demo limitations:** Stay names, availability and prices are sample data. A saved booking is only a request record; it is not a confirmed hotel reservation, does not check live inventory and does not process payment. Configure HTTPS before entering real credentials or personal information. Use a unique password.

## Local development

Requires Node.js 20+ and npm.

```bash
npm install
cp .env.example .env
openssl rand -hex 32
```

Put the generated value in `JWT_SECRET` in `.env`; never commit that file.

Start the API and frontend in separate terminals:

```bash
npm run dev:api
npm run dev
```

Open http://localhost:5173. Vite proxies `/api` to the API on port 3001. The default local SQLite location is `data/holidays.sqlite`.

## Amazon Linux 2023 EC2 deployment (no Docker)

The deployment script is designed to work even when you cloned the repository under `/home/ec2-user/Holidays`. It detects its own checkout path and installs the application into the canonical runtime path `/opt/holidays`, which is also used by systemd.

### 1. Install prerequisites

```bash
sudo dnf install -y nodejs22 nodejs22-npm git nginx gcc-c++ make python3
sudo alternatives --set node /usr/bin/node-22
node --version
npm --version
```

Use Node.js 20 or newer. If your AMI provides a different supported Node.js package, verify that `node --version` is 20+ and that `/usr/bin/node` resolves to it.

### 2. Clone or update the repository as ec2-user

For a new checkout:

```bash
cd /home/ec2-user
git clone https://github.com/avi-79/Holidays.git
cd Holidays
```

For an existing checkout:

```bash
cd /home/ec2-user/Holidays
git pull --ff-only
```

Do not run `npm` from `/home/ec2-user`; run the deployment script from inside the repository directory. Do not use `sudo git clone` into your home directory.

### 3. Run the deployment script

```bash
cd /home/ec2-user/Holidays
sudo bash deploy/ec2-deploy.sh
```

The script:

1. Detects the repository directory from the script location.
2. Copies the source to `/opt/holidays` (without copying local secrets, databases, Git metadata or existing node_modules).
3. Installs dependencies, builds the Vite frontend, then prunes development-only packages.
4. Publishes the built frontend to `/var/www/holidays`.
5. Creates the restricted `holidays` service account and persistent database directory.
6. Creates `/etc/holidays/holidays.env` with a generated JWT secret if the file does not already exist. Existing environment configuration is preserved.
7. Installs/enables the systemd API service and checks `/api/health`.
8. Installs the supplied Nginx server block only if `/etc/nginx/conf.d/holidays.conf` does not already exist, then tests and reloads Nginx.

The script does not print the JWT secret. Keep `/etc/holidays/holidays.env` private.

### 4. Verify the deployment

```bash
sudo systemctl status holidays-api --no-pager
curl -i http://127.0.0.1:3001/api/health
sudo nginx -t
curl -I http://127.0.0.1/
```

The API health endpoint should return HTTP 200 and JSON similar to:

```json
{"status":"ok","service":"holidays-api"}
```

If the API is not active, inspect:

```bash
sudo journalctl -u holidays-api -n 80 --no-pager
sudo systemctl cat holidays-api
sudo ss -lntp | grep 3001
```

If Nginx reports a configuration conflict, inspect `sudo nginx -T` before changing existing server blocks. The supplied config is in `/etc/nginx/conf.d/holidays.conf`. Keep port 3001 bound to localhost and do not add it to the EC2 security group.

### 5. HTTPS is required before real account use

The deployment script sets `COOKIE_SECURE=false` only to permit temporary HTTP smoke testing. Do not enter real passwords or personal information over public plain HTTP.

Configure a TLS certificate and HTTP-to-HTTPS redirect first. Then update the environment file:

```ini
COOKIE_SECURE=true
```

Restart the API:

```bash
sudo systemctl restart holidays-api
sudo systemctl status holidays-api --no-pager
```

Only expose approved web ports (normally 443, and 80 for certificate/redirect handling) to approved source networks. Never expose API port 3001 publicly.

### Updating an existing EC2 deployment

```bash
cd /home/ec2-user/Holidays
git pull --ff-only
sudo bash deploy/ec2-deploy.sh
```

The script keeps the existing SQLite database and environment file. Back up the database before upgrades.


## Microservices architecture (current development target)

The Holidays application is being separated into three Node.js services. The frontend remains the existing Holidays experience and sends API requests through one gateway.

| Component | Port | Responsibility |
|---|---:|---|
| Web frontend | Served by Gateway | Holidays stay discovery and account UI |
| API Gateway | 8080 | Public API entry point, login/session handling and routing |
| Accommodation Service | 8081 | Stay catalogue and inventory reservation/release |
| Booking Service | 8082 | User booking records, create and cancel |\n| Payment Service (demo) | 8083 | Simulated payment recording and booking confirmation |
| PostgreSQL | 5432 | Three isolated databases: `holidays_gateway`, `holidays_accommodation`, `holidays_booking` |

The services bind to loopback on the EC2 host. Only Nginx should be exposed publicly. The Gateway owns account records and session cookies; the Booking Service owns booking records; the Accommodation Service owns date-based inventory; the Payment Service stores demo payment records and confirms pending bookings. Booking calls the Accommodation Service API rather than reading its database. A booking starts in `PENDING_PAYMENT`; the Payment Service provides a simulated test-payment step and then marks it `CONFIRMED`. No real card or bank details are collected, and no money is charged.

### Local development

Requires Node.js 20+ and PostgreSQL. Create the four databases/roles using `deploy/postgres/01-create-databases.sql` after replacing its sample passwords. Configure the environment variables from `deploy/microservices.env.example` in your shell (do not commit real secrets), then run each service in its own terminal:

```bash
npm install
npm run dev:accommodation
npm run dev:booking
npm run dev:gateway
```

The Vite development server proxies `/api` to port 8080. Start the payment service with `npm run start:payment` (after setting `PORT=8083` and `DATABASE_URL` to the payment database). In a fifth terminal run `npm run dev` and open http://localhost:5173.

### Amazon Linux 2023 deployment (without Docker)

This is a new PostgreSQL-backed deployment path; it does not automatically migrate the old SQLite users/bookings database. Back up the existing SQLite file and plan an explicit data migration before switching an existing live instance.

1. Install Node.js 20+, PostgreSQL and Nginx on the EC2 host. Keep PostgreSQL and all three Node service ports private.
2. Create the three PostgreSQL roles and databases using `deploy/postgres/01-create-databases.sql`. Replace all sample passwords first.
3. The payment role/database is included in `deploy/postgres/01-create-databases.sql`. Copy `deploy/microservices.env.example` to `/etc/holidays/microservices.env`; set all four PostgreSQL URLs, a unique random JWT secret of at least 32 characters, a separate long random `INTERNAL_SERVICE_TOKEN`, and `COOKIE_SECURE=true` after HTTPS is configured. Protect the file with owner root and mode 0640.
4. Clone/update this repository and run:

```bash
sudo bash deploy/ec2-deploy-microservices.sh
```

The script builds the frontend, installs four systemd services, starts them and checks the gateway health endpoint. Nginx proxies API traffic to port 8080 and serves the frontend through the gateway.

### Verify services

```bash
sudo systemctl status holidays-gateway holidays-accommodation holidays-booking --no-pager
curl -i http://127.0.0.1:8080/api/health
curl -i http://127.0.0.1:8080/api/stays
sudo journalctl -u holidays-gateway -n 60 --no-pager
sudo journalctl -u holidays-accommodation -n 60 --no-pager
sudo journalctl -u holidays-booking -n 60 --no-pager
```

Do not expose ports 8080, 8081, 8082 or 5432 in the EC2 security group. Use Nginx and HTTPS for browser traffic. The old SQLite deployment script and old SQLite API are retained for reference during this migration; use the new microservices deployment script for the PostgreSQL architecture.

## Legacy SQLite database (migration reference)

The earlier single-process SQLite implementation remains in the repository for reference only. The microservices target above uses PostgreSQL. Existing SQLite accounts and bookings are not automatically copied to PostgreSQL.

## Database

- `users`: unique email and bcrypt password hash (never plaintext passwords)
- `bookings`: reference, owner, selected sample stay, dates, guest count and contact details
- Database file: `/var/lib/holidays/holidays.sqlite`
- SQLite WAL mode and foreign-key enforcement are enabled by the API

Back up the database regularly. Keep this single-instance SQLite deployment on one EC2 instance. For multi-replica Kubernetes or production scale, migrate to PostgreSQL or another managed database with persistent storage.

## API endpoints

- `GET /api/health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/bookings` (authenticated)
- `POST /api/bookings` (authenticated)

The existing Docker/Kubernetes manifests are frontend starters. The API and persistent database need their own deployment and persistent storage before those environments can use account and database features.

Holidays · Developed by Avinesh · 2026
