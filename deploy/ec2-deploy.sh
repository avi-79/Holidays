#!/usr/bin/env bash
set -Eeuo pipefail

cat >&2 <<'NOTICE'
This is the LEGACY single-process SQLite deployment script.
The current Holidays architecture uses four Node.js microservices and PostgreSQL.
Do not use this script for a new or upgraded microservices deployment.

Use:
  sudo bash deploy/ec2-deploy-microservices.sh

The legacy script is retained only as a reference for the previous SQLite setup.
NOTICE
exit 2
