#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

command -v docker >/dev/null 2>&1 || { echo "Docker CLI not found. Install Docker Engine/Desktop first." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is unavailable. Install the Compose plugin or update Docker Desktop." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker engine is not running. Start Docker and retry." >&2; exit 1; }

if [[ ! -f .env.docker ]]; then
  [[ -f .env.docker.example ]] || { echo ".env.docker.example is missing. Pull the latest Holidays repository." >&2; exit 1; }
  cp .env.docker.example .env.docker
  sed -i \
    -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 32)/" \
    -e "s/^GATEWAY_DB_PASSWORD=.*/GATEWAY_DB_PASSWORD=$(openssl rand -hex 32)/" \
    -e "s/^ACCOMMODATION_DB_PASSWORD=.*/ACCOMMODATION_DB_PASSWORD=$(openssl rand -hex 32)/" \
    -e "s/^BOOKING_DB_PASSWORD=.*/BOOKING_DB_PASSWORD=$(openssl rand -hex 32)/" \
    -e "s/^PAYMENT_DB_PASSWORD=.*/PAYMENT_DB_PASSWORD=$(openssl rand -hex 32)/" \
    -e "s/^JWT_SECRET=.*/JWT_SECRET=$(openssl rand -hex 32)/" \
    -e "s/^INTERNAL_SERVICE_TOKEN=.*/INTERNAL_SERVICE_TOKEN=$(openssl rand -hex 32)/" \
    .env.docker
  echo "Created .env.docker with unique local secrets. It is excluded from Git."
fi

if [[ "$#" -eq 0 ]]; then
  set -- up -d --build
fi

exec docker compose --env-file .env.docker "$@"
