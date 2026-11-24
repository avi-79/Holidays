#!/usr/bin/env bash
set -Eeuo pipefail

# Deploy the PostgreSQL-backed Holidays microservices on Amazon Linux 2023.
# Run from any checkout location: sudo bash deploy/ec2-deploy-microservices.sh

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash deploy/ec2-deploy-microservices.sh" >&2
  exit 1
fi

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="/opt/holidays"
ENV_DIR="/etc/holidays"
ENV_FILE="${ENV_DIR}/microservices.env"
SYSTEMD_DIR="/etc/systemd/system"

for command_name in node npm tar systemctl curl nginx; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command_name}" >&2
    exit 1
  }
done

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
if (( NODE_MAJOR < 20 )); then
  echo "Node.js 20 or newer is required; found $(node --version)." >&2
  exit 1
fi

for required in package.json services/api-gateway/index.js services/accommodation-service/index.js services/booking-service/index.js services/payment-service/index.js deploy/holidays.nginx.conf; do
  [[ -f "${ROOT}/${required}" ]] || {
    echo "Required project file is missing: ${ROOT}/${required}" >&2
    exit 1
  }
done

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}." >&2
  echo "Create it from ${ROOT}/deploy/microservices.env.example and configure all database passwords/secrets first." >&2
  exit 1
fi

required_keys=(
  JWT_SECRET
  COOKIE_SECURE
  GATEWAY_DATABASE_URL
  ACCOMMODATION_DATABASE_URL
  BOOKING_DATABASE_URL
  PAYMENT_DATABASE_URL
  INTERNAL_SERVICE_TOKEN
  ACCOMMODATION_URL
  BOOKING_URL
  PAYMENT_URL
)
for key in "${required_keys[@]}"; do
  if ! grep -Eq "^[[:space:]]*${key}=" "${ENV_FILE}"; then
    echo "Missing ${key} in ${ENV_FILE}" >&2
    exit 1
  fi
done

if grep -Eq 'CHANGE_ME|REPLACE_WITH_' "${ENV_FILE}"; then
  echo "The environment file still contains placeholder values. Replace every placeholder before deployment." >&2
  exit 1
fi

JWT_SECRET="$(sed -n 's/^JWT_SECRET=//p' "${ENV_FILE}" | head -n 1)"
INTERNAL_TOKEN="$(sed -n 's/^INTERNAL_SERVICE_TOKEN=//p' "${ENV_FILE}" | head -n 1)"
if (( ${#JWT_SECRET} < 32 )); then
  echo "JWT_SECRET must contain at least 32 characters." >&2
  exit 1
fi
if (( ${#INTERNAL_TOKEN} < 32 )); then
  echo "INTERNAL_SERVICE_TOKEN must contain at least 32 characters." >&2
  exit 1
fi

getent group holidays >/dev/null 2>&1 || groupadd --system holidays
id holidays >/dev/null 2>&1 || useradd --system --gid holidays --home-dir "${APP_DIR}" --shell /sbin/nologin holidays

install -d -o root -g holidays -m 0750 "${APP_DIR}" "${ENV_DIR}"
install -d -o root -g root -m 0755 /etc/nginx/conf.d

echo "Copying Holidays source to ${APP_DIR}..."
tar -C "${ROOT}" \
  --exclude=.git --exclude=node_modules --exclude=dist --exclude=data \
  --exclude=.env --exclude='*.sqlite' --exclude='*.sqlite-*' \
  -cf - . | tar -C "${APP_DIR}" -xf -

cd "${APP_DIR}"
echo "Installing Node.js dependencies..."
npm install --include=dev --no-audit --no-fund

echo "Building the frontend..."
npm run build

echo "Removing development-only dependencies..."
npm prune --omit=dev --no-audit --no-fund

chown -R root:holidays "${APP_DIR}"
chmod -R g+rX,o-rwx "${APP_DIR}"
chown root:holidays "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"

for service in accommodation booking payment gateway; do
  service_file="${APP_DIR}/deploy/holidays-${service}.service"
  [[ -f "${service_file}" ]] || {
    echo "Missing systemd unit: ${service_file}" >&2
    exit 1
  }
  install -m 0644 "${service_file}" "${SYSTEMD_DIR}/holidays-${service}.service"
done

install -m 0644 "${APP_DIR}/deploy/holidays.nginx.conf" /etc/nginx/conf.d/holidays.conf

# Disable the stock Amazon Linux welcome site without overwriting an earlier backup.
if [[ -f /etc/nginx/conf.d/default.conf && ! -f /etc/nginx/conf.d/default.conf.disabled-by-holidays ]]; then
  mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled-by-holidays
fi

echo "Validating Nginx configuration..."
nginx -t

systemctl daemon-reload
systemctl enable holidays-accommodation holidays-booking holidays-payment holidays-gateway
systemctl restart holidays-accommodation
systemctl restart holidays-booking
systemctl restart holidays-payment
systemctl restart holidays-gateway
systemctl enable nginx

healthy=0
for attempt in $(seq 1 45); do
  if curl --fail --silent http://127.0.0.1:8081/health >/dev/null \
    && curl --fail --silent http://127.0.0.1:8082/health >/dev/null \
    && curl --fail --silent http://127.0.0.1:8083/health >/dev/null \
    && curl --fail --silent http://127.0.0.1:8080/api/health >/dev/null; then
    healthy=1
    break
  fi
  sleep 2
done

if [[ "${healthy}" -ne 1 ]]; then
  echo "One or more Holidays services did not become healthy. Recent logs follow:" >&2
  for service in accommodation booking payment gateway; do
    echo "===== holidays-${service} =====" >&2
    journalctl -u "holidays-${service}" -n 60 --no-pager >&2 || true
  done
  exit 1
fi

systemctl reload nginx 2>/dev/null || systemctl restart nginx
if ! curl --fail --silent --show-error http://127.0.0.1/api/health; then
  echo "Gateway is healthy directly, but the Nginx API health check failed." >&2
  journalctl -u nginx -n 40 --no-pager >&2 || true
  exit 1
fi

echo
echo "Holidays microservices deployment completed."
echo "Gateway:        127.0.0.1:8080"
echo "Accommodation:  127.0.0.1:8081"
echo "Booking:        127.0.0.1:8082"
echo "Payment demo:   127.0.0.1:8083 (simulation only; no money is charged)"
echo "Public web:     Nginx on port 80 (configure HTTPS before real account use)"
echo "Do not expose ports 8080-8083 or PostgreSQL 5432 to the internet."
