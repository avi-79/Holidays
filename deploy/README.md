# Holidays deployment files

This folder contains the current no-Docker, PostgreSQL-backed deployment for Amazon Linux 2023.

## Current architecture

| Component | Port | Database |
|---|---:|---|
| API Gateway + React frontend | 8080 | holidays_gateway |
| Accommodation Service | 8081 | holidays_accommodation |
| Booking Service | 8082 | holidays_booking |
| Demo Payment Service | 8083 | holidays_payment |
| Nginx | 80 (HTTPS should be added) | — |

All Node services bind to 127.0.0.1. Nginx is the public entry point. The payment service is a simulation only: it does not accept real card details or charge money.

## Migration warning

The old SQLite deployment is not automatically migrated. Back up the old SQLite database and plan a deliberate data migration before replacing an existing instance. The legacy `ec2-deploy.sh` is intentionally disabled; use only `ec2-deploy-microservices.sh` for the current architecture.

## 1. Install prerequisites

On Amazon Linux 2023, install Node.js 20+, npm, PostgreSQL server/client, Nginx, Git and build tools using package names available on your AMI. Verify:

```bash
node --version
npm --version
psql --version
sudo nginx -v
```

Initialize and start PostgreSQL using the versioned PostgreSQL service name installed on your host. Confirm local access:

```bash
sudo systemctl list-unit-files | grep -i postgres
sudo -u postgres psql -c 'SELECT version();'
```

Do not open port 5432 in the EC2 security group.

## 2. Clone or update the repository

```bash
cd /home/ec2-user
git clone https://github.com/avi-79/Holidays.git
cd Holidays
```

For an existing checkout:

```bash
cd /home/ec2-user/Holidays
git pull --ff-only origin main
```

## 3. Create four PostgreSQL databases

Edit `postgres/01-create-databases.sql` and replace all four `CHANGE_ME_...` password values with strong, unique passwords. URL-safe hexadecimal passwords are recommended to avoid connection-string escaping issues.

Run from the repository root:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -f deploy/postgres/01-create-databases.sql
```

If the host already has the original three databases and only needs the Payment database, use `postgres/02-create-payment-database.sql` instead of rerunning the full bootstrap. Do not run both scripts for a fresh installation.

## 4. Configure the environment

```bash
sudo install -d -o root -g holidays -m 0750 /etc/holidays
sudo cp deploy/microservices.env.example /etc/holidays/microservices.env
sudo nano /etc/holidays/microservices.env
```

Replace every placeholder. The four PostgreSQL URL passwords must match the passwords used in the SQL bootstrap. Generate two independent secrets:

```bash
openssl rand -hex 32
openssl rand -hex 32
```

Use one for `JWT_SECRET` and the other for `INTERNAL_SERVICE_TOKEN`. Keep `COOKIE_SECURE=false` only for a temporary private HTTP smoke test. After HTTPS is configured, set it to `true`.

## 5. Deploy all four services

From the repository root:

```bash
sudo bash deploy/ec2-deploy-microservices.sh
```

The script validates required files and environment placeholders, copies the app to `/opt/holidays`, installs dependencies, builds the frontend, installs four systemd units, starts the services, checks their health endpoints, validates Nginx and checks the gateway through Nginx.

## 6. Verify

```bash
sudo systemctl status holidays-accommodation holidays-booking holidays-payment holidays-gateway --no-pager
sudo nginx -t
curl -i http://127.0.0.1:8081/health
curl -i http://127.0.0.1:8082/health
curl -i http://127.0.0.1:8083/health
curl -i http://127.0.0.1:8080/api/health
curl -i http://127.0.0.1/api/health
curl -i http://127.0.0.1/api/stays
```

For failures:

```bash
sudo journalctl -u holidays-gateway -n 80 --no-pager
sudo journalctl -u holidays-accommodation -n 80 --no-pager
sudo journalctl -u holidays-booking -n 80 --no-pager
sudo journalctl -u holidays-payment -n 80 --no-pager
```

## 7. Security before real account use

- Configure a valid TLS certificate and HTTPS before using real account credentials.
- Set `COOKIE_SECURE=true` and restart services after HTTPS is active.
- Expose only approved web ports (normally 443, and 80 for redirect/certificate handling).
- Never expose ports 8080–8083 or PostgreSQL 5432 publicly.
- Keep `/etc/holidays/microservices.env` owned by root with mode 0640.
- Stay catalogue and prices are sample data. Demo payment does not process real money.
