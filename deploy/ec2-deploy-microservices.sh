#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash deploy/ec2-deploy-microservices.sh" >&2; exit 1; fi
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR=/opt/holidays
ENV_FILE=/etc/holidays/microservices.env
for c in node npm tar systemctl curl; do command -v "$c" >/dev/null || { echo "Missing command: $c" >&2; exit 1; }; done
[[ "$(node -p 'Number(process.versions.node.split(".")[0])')" -ge 20 ]] || { echo "Node.js 20+ required"; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "Create $ENV_FILE from deploy/microservices.env.example, set unique strong passwords and JWT_SECRET, then rerun."; exit 1; }
for k in GATEWAY_DATABASE_URL ACCOMMODATION_DATABASE_URL BOOKING_DATABASE_URL PAYMENT_DATABASE_URL INTERNAL_SERVICE_TOKEN JWT_SECRET; do grep -q "^$k=" "$ENV_FILE" || { echo "Missing $k in $ENV_FILE"; exit 1; }; done
getent group holidays >/dev/null 2>&1 || groupadd --system holidays
id holidays >/dev/null 2>&1 || useradd --system --gid holidays --home-dir "$APP_DIR" --shell /sbin/nologin holidays
install -d -o root -g holidays -m 0750 "$APP_DIR"
tar -C "$ROOT" --exclude=.git --exclude=node_modules --exclude=dist --exclude=data --exclude=.env -cf - . | tar -C "$APP_DIR" -xf -
cd "$APP_DIR"
npm install --include=dev --no-audit --no-fund
npm run build
npm prune --omit=dev --no-audit --no-fund
chown -R root:holidays "$APP_DIR"; chmod -R g+rX,o-rwx "$APP_DIR"
chown root:holidays "$ENV_FILE"; chmod 0640 "$ENV_FILE"
for service in accommodation booking payment gateway; do install -m 0644 "$APP_DIR/deploy/holidays-$service.service" "/etc/systemd/system/holidays-$service.service"; done
systemctl daemon-reload
systemctl enable --now holidays-accommodation holidays-booking holidays-payment holidays-gateway
healthy=0
for i in $(seq 1 30); do if curl -fsS http://127.0.0.1:8080/api/health >/dev/null && curl -fsS http://127.0.0.1:8081/health >/dev/null && curl -fsS http://127.0.0.1:8082/health >/dev/null && curl -fsS http://127.0.0.1:8083/health >/dev/null; then healthy=1; break; fi; sleep 1; done
if [[ "$healthy" -ne 1 ]]; then
  echo "Gateway health check failed. Service logs:" >&2
  for service in accommodation booking payment gateway; do journalctl -u "holidays-$service" -n 35 --no-pager >&2 || true; done
  exit 1
fi
if command -v nginx >/dev/null 2>&1; then
 if [[ -f /etc/nginx/conf.d/default.conf ]]; then mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled-by-holidays; fi
 install -m 0644 "$APP_DIR/deploy/holidays.nginx.conf" /etc/nginx/conf.d/holidays.conf
 nginx -t
 systemctl enable nginx >/dev/null 2>&1 || true
 systemctl reload nginx 2>/dev/null || systemctl start nginx
 curl -fsS http://127.0.0.1/api/health
 echo
fi
echo "Holidays microservices deployed. Gateway: 8080; Accommodation: 8081; Booking: 8082; Payment demo: 8083."
echo "Do not expose service ports 8080-8083 directly to the internet; use Nginx/HTTPS."
