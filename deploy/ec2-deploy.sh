#!/usr/bin/env bash
set -Eeuo pipefail

# Run from any checkout location, for example:
#   cd ~/Holidays && sudo bash deploy/ec2-deploy.sh
if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash deploy/ec2-deploy.sh" >&2
  exit 1
fi

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="/opt/holidays"
WEB_ROOT="/var/www/holidays"
ENV_DIR="/etc/holidays"
ENV_FILE="${ENV_DIR}/holidays.env"
SERVICE_FILE="/etc/systemd/system/holidays-api.service"

if [[ ! -f "${REPO_ROOT}/package.json" || ! -f "${REPO_ROOT}/server/index.js" ]]; then
  echo "Could not find package.json and server/index.js in ${REPO_ROOT}." >&2
  exit 1
fi

for command_name in node npm tar openssl curl systemctl; do
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

echo "Deploying checkout ${REPO_ROOT} to ${APP_DIR}"

getent group holidays >/dev/null 2>&1 || groupadd --system holidays
if ! id holidays >/dev/null 2>&1; then
  useradd --system --gid holidays --home-dir "${APP_DIR}" --shell /sbin/nologin holidays
fi

install -d -o root -g holidays -m 0750 "${APP_DIR}"
if [[ "${REPO_ROOT}" != "${APP_DIR}" ]]; then
  tar -C "${REPO_ROOT}" \
    --exclude=.git --exclude=node_modules --exclude=dist --exclude=data --exclude=.env \
    -cf - . | tar -C "${APP_DIR}" -xf -
fi

cd "${APP_DIR}"
echo "Installing application dependencies..."
npm install --include=dev --no-audit --no-fund
echo "Building the React frontend..."
npm run build
echo "Removing development-only dependencies..."
npm prune --omit=dev --no-audit --no-fund

install -d -o root -g root -m 0755 "${WEB_ROOT}"
cp -a "${APP_DIR}/dist/." "${WEB_ROOT}/"
find "${WEB_ROOT}" -type d -exec chmod 0755 {} +
find "${WEB_ROOT}" -type f -exec chmod 0644 {} +

# Ensure the existing SQLite directory and database are writable by the service.
# Do not remove or recreate the database file: it may contain user bookings.
install -d -o holidays -g holidays -m 0750 /var/lib/holidays
find /var/lib/holidays -maxdepth 1 -type f -name 'holidays.sqlite*' \
  -exec chown holidays:holidays {} + -exec chmod 0640 {} +
install -d -o root -g holidays -m 0750 "${ENV_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  JWT_SECRET="$(openssl rand -hex 32)"
  umask 027
  cat > "${ENV_FILE}" <<EOF
NODE_ENV=production
PORT=3001
HOST=127.0.0.1
DB_PATH=/var/lib/holidays/holidays.sqlite
JWT_SECRET=${JWT_SECRET}
COOKIE_SECURE=false
EOF
fi

CURRENT_SECRET="$(sed -n 's/^JWT_SECRET=//p' "${ENV_FILE}" | head -n 1)"
if [[ "${#CURRENT_SECRET}" -lt 32 || "${CURRENT_SECRET}" == "REPLACE_WITH_A_RANDOM_SECRET" ]]; then
  NEW_SECRET="$(openssl rand -hex 32)"
  if grep -q '^JWT_SECRET=' "${ENV_FILE}"; then
    sed -i "s/^JWT_SECRET=.*/JWT_SECRET=${NEW_SECRET}/" "${ENV_FILE}"
  else
    printf '\nJWT_SECRET=%s\n' "${NEW_SECRET}" >> "${ENV_FILE}"
  fi
fi

ensure_env() {
  local key="$1"
  local value="$2"
  if ! grep -q "^${key}=" "${ENV_FILE}"; then
    printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
  fi
}
ensure_env NODE_ENV production
ensure_env PORT 3001
ensure_env HOST 127.0.0.1
ensure_env DB_PATH /var/lib/holidays/holidays.sqlite
ensure_env COOKIE_SECURE false

# Keep the API bound to loopback even if an older env file used another host.
sed -i 's/^HOST=.*/HOST=127.0.0.1/' "${ENV_FILE}"
chown root:holidays "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"

chown -R root:holidays "${APP_DIR}"
chmod -R g+rX,o-rwx "${APP_DIR}"

install -m 0644 "${APP_DIR}/deploy/holidays-api.service" "${SERVICE_FILE}"
systemctl daemon-reload
systemctl enable --now holidays-api

echo "Waiting for the API health endpoint..."
healthy=0
for attempt in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:3001/api/health >/dev/null; then
    healthy=1
    break
  fi
  sleep 1
done

if [[ "${healthy}" -ne 1 ]]; then
  echo "Holidays API did not become healthy. Recent service logs:" >&2
  journalctl -u holidays-api -n 60 --no-pager >&2 || true
  exit 1
fi

echo "API health check:"
curl --fail --silent http://127.0.0.1:3001/api/health
echo

# Install and activate the repository-managed Nginx site configuration.
if command -v nginx >/dev/null 2>&1; then
  install -d -m 0755 /etc/nginx/conf.d
  install -m 0644 "${APP_DIR}/deploy/holidays.nginx.conf" /etc/nginx/conf.d/holidays.conf

  # Disable the stock Amazon Linux welcome page if it would compete for port 80.
  if [[ -f /etc/nginx/conf.d/default.conf ]]; then
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
  fi

  if nginx -t; then
    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl reload nginx 2>/dev/null || systemctl start nginx
    echo "Nginx configuration test passed."
  else
    echo "ERROR: Nginx configuration test failed. Run sudo nginx -t and inspect the reported file/line." >&2
    exit 1
  fi

  echo "Checking API through Nginx..."
  if ! curl --fail --silent --show-error http://127.0.0.1/api/health; then
    echo "ERROR: API health check through Nginx failed." >&2
    journalctl -u holidays-api -n 40 --no-pager >&2 || true
    exit 1
  fi
  echo
else
  echo "Nginx is not installed; install/configure it separately to serve the website." >&2
fi

echo
echo "Deployment script finished."
echo "App source: ${APP_DIR}"
echo "Frontend files: ${WEB_ROOT}"
echo "SQLite database: /var/lib/holidays/holidays.sqlite"
echo "API: http://127.0.0.1:3001 (localhost only)"
echo "IMPORTANT: COOKIE_SECURE=false is for temporary HTTP testing only."
echo "Configure HTTPS and set COOKIE_SECURE=true before using real credentials."
