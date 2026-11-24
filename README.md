# Holidays

A responsive, TUI-inspired stay discovery and booking-request demo. Developed by Avinesh.

## Features
- Responsive destination search, stay filters, sorting and favourites
- Account registration, login and logout
- Passwords hashed with bcrypt and signed sessions in HttpOnly cookies
- SQLite database for user accounts and booking requests
- Each signed-in user can view only their own booking requests
- Rate-limited authentication endpoints and server-side input validation

> **Important:** This is a learning/demo application. Stay information and prices are sample data. A saved booking is a request record in your database; it does not confirm a real hotel reservation, check live availability, or take payment. Configure HTTPS before using real accounts or personal information. Use a unique password.

## Local development

Requires Node.js 20+ and npm.

```bash
npm install
cp .env.example .env
openssl rand -hex 32
``
Put the generated value in `JWT_SECRET` in `.env`; never commit that file.

Start the API and frontend in separate terminals:
```bash
npm run dev:api
npm run dev
``
Open http://localhost:5173. Vite proxies `/api` requests to the API on port 3001. SQLite is stored in `data/holidays.sqlite`.

## EC2 deployment without Docker

The following deploys both the frontend and API on one EC2 instance. Keep API port 3001 private (localhost only); only Nginx serves browser traffic.

1. Pull the repository into `/opt/holidays` and install dependencies:
   ```bash
   sudo git clone https://github.com/avi-79/Holidays.git /opt/holidays
   cd /opt/holidays
   npm install
   npm run build
   sudo mkdir -p /var/www/holidays
   sudo cp -r dist/* /var/www/holidays/
   ``

2. Create a dedicated service user and persistent database directory:
   ```bash
   sudo useradd --system --home /opt/holidays --shell /sbin/nologin holidays
   sudo mkdir -p /var/lib/holidays /etc/holidays
   sudo chown -R holidays:holidays /var/lib/holidays
   sudo chown -R root:holidays /opt/holidays
   sudo chmod -R o-rwx /opt/holidays
   ``

3. Create `/etc/holidays/holidays.env` with a strong secret:
   ```bash
   sudo sh -c 'umask 077; cat > /etc/holidays/holidays.env <<EOF
   NODE_ENV=production
   PORT=3001
   HOST=127.0.0.1
   DB_PATH=/var/lib/holidays/holidays.sqlite
   JWT_SECRET=REPLACE_WITH_A_RANDOM_SECRET
   COOKIE_SECURE=false
   EOF'
   ``
   Generate a secret using `openssl rand -hex 32` and replace the placeholder. Keep this file private. `COOKIE_SECURE=false` is only for temporary HTTP testing; configure HTTPS and set it to `true` before using real accounts.

4. Create `/etc/systemd/system/holidays-api.service`:
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

5. Install production dependencies as the service user and start the API:
   ```bash
   sudo npm install --omit=dev --prefix /opt/holidays
   sudo chown root:holidays /etc/holidays/holidays.env
   sudo chmod 640 /etc/holidays/holidays.env
   sudo systemctl daemon-reload
   sudo systemctl enable --now holidays-api
   sudo systemctl status holidays-api
   curl http://127.0.0.1:3001/api/health
   ``

6. Configure your host Nginx server block (for example `/etc/nginx/conf.d/holidays.conf`):
   ```nginx
   server {
       listen 80;
       server_name _;
       root /var/www/holidays;
       index index.html;

       location /api/ {
           proxy_pass http://127.0.0.1:3001;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }

       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```
   Run `sudo nginx -t && sudo systemctl reload nginx`. Do not add port 3001 to the EC2 security group. The API listens on localhost only.

**HTTPS:** Before using real accounts, configure a TLS certificate and redirect HTTP to HTTPS, then set `COOKIE_SECURE=true` in `/etc/holidays/holidays.env` and restart `holidays-api`. Do not transmit passwords over public plain HTTP.

**Updates:** After pulling new source, run `npm install`, `npm run build`, copy the new `dist` files to `/var/www/holidays`, and restart `holidays-api` if backend files changed.

## Database

- `users`: unique email and bcrypt password hash (never plain-text passwords)
- `bookings`: booking reference, owner, selected sample stay, dates, guests and contact details
- Parameterized SQL, server-side validation, per-account booking access and authentication rate limits
- Database path: `/var/lib/holidays/holidays.sqlite`

Back up the database regularly. Keep the API on one instance when using local SQLite; for multi-replica Kubernetes/production use PostgreSQL or another managed database.

## API endpoints
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/bookings` (authenticated)
- `POST /api/bookings` (authenticated)
- `GET /api/health`

The existing Docker/Kubernetes manifests are frontend starters. The API and persistent database need their own deployment and persistent storage before those environments can use account and database features.

Holidays · Developed by Avinesh · 2026
