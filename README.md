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
