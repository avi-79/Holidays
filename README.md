# Holidays

A responsive, TUI-inspired stay discovery and booking-request demo. Developed by Avinesh.

## Features
- Responsive destination search, stay filters, sorting and favourites
- Account registration, login and logout
- Passwords hashed with bcrypt and signed sessions in HttpOnly cookies
- SQLite database for users and booking requests
- Each signed-in user can view only their own booking requests
- Rate-limited authentication endpoints and server-side input validation

> **Important:** This is a learning/demo application. Stay information and prices are sample data. A saved booking is only a request record in your database; it does not confirm a real hotel reservation, check live availability, or take payment. Use HTTPS before entering real personal information. Do not reuse an important password.

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
Open http://localhost:5173. Vite proxies `/api` to port 3001. SQLite is stored in `data/holidays.sqlite`.

## EC2 deployment without Docker
Build and copy the frontend:
```bash
npm ci
npm run build
sudo mkdir -p /var/www/holidays
sudo cp -r dist/* /var/www/holidays/
``

Deploy the API source to `/opt/holidays`, then install production dependencies:
```bash
cd /opt/holidays
npm ci --omit=dev
sudo mkdir -p /var/lib/holidays /etc/holidays
sudo chown -R holidays:holidays /var/lib/holidays
``
Create a private environment file at `/etc/holidays/holidays.env` with:
```ini
NODE_ENV=production
PORT=3001
HOST=127.0.0.1
DB_PATH=/var/lib/holidays/holidays.sqlite
JWT_SECRET=REPLACE_WITH_OUTPUT_OF_OPENSSL_RAND_HEX_32
COOKIE_SECURE=false
``
Generate the secret with `openssl rand -hex 32`. Keep the env file private. `COOKIE_SECURE=false` is only for temporary HTTP testing; configure HTTPS and set it to `true` before using real accounts.

Create `/etc/systemd/system/holidays-api.service`:
```ini
[Unit]
Description=Holidays API
After=network.target

[Service]
Type=simple
User=holidays
Group=holidays
WorkingDirectory=/opt/holidays
EnvironmentFile=/etc/holidays/holidays.env
ExecStart=/usr/bin/node /opt/holidays/server/index.js
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
``
Create the service user and start it:
```bash
sudo useradd --system --home /opt/holidays --shell /sbin/nologin holidays
sudo chown -R holidays:holidays /opt/holidays /var/lib/holidays
sudo chown root:holidays /etc/holidays/holidays.env
sudo chmod 640 /etc/holidays/holidays.env
sudo systemctl daemon-reload
sudo systemctl enable --now holidays-api
sudo systemctl status holidays-api
curl http://127.0.0.1:3001/api/health
``

Add this location inside the host Nginx server block:
```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
``
Then run `sudo nginx -t && sudo systemctl reload nginx`. Do not open port 3001 in the EC2 security group; the API listens only on localhost.

## Database and limitations
- `users`: unique email and bcrypt password hash (never plain-text passwords)
- `bookings`: user-owned booking request, selected sample stay, dates, guests and contact details
- Parameterized SQL, server-side validation, per-account booking access and authentication rate limits
- Back up `/var/lib/holidays/holidays.sqlite`. Keep the API on one instance when using local SQLite; for multi-replica Kubernetes/production use PostgreSQL or another managed database.

The current Docker/Kubernetes manifests remain frontend starters; the API and persistent database need their own deployment and persistent storage before using those environments.

## API
- `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/bookings`, `POST /api/bookings` (authenticated)
- `GET /api/health`

Holidays · Developed by Avinesh · 2026
