#!/bin/sh
set -eu
: "${GATEWAY_DB_PASSWORD:?GATEWAY_DB_PASSWORD is required}"
: "${ACCOMMODATION_DB_PASSWORD:?ACCOMMODATION_DB_PASSWORD is required}"
: "${BOOKING_DB_PASSWORD:?BOOKING_DB_PASSWORD is required}"
: "${PAYMENT_DB_PASSWORD:?PAYMENT_DB_PASSWORD is required}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v gateway_password="$GATEWAY_DB_PASSWORD" \
  -v accommodation_password="$ACCOMMODATION_DB_PASSWORD" \
  -v booking_password="$BOOKING_DB_PASSWORD" \
  -v payment_password="$PAYMENT_DB_PASSWORD" <<'SQL'
CREATE ROLE holidays_gateway LOGIN PASSWORD :'gateway_password';
CREATE ROLE holidays_accommodation LOGIN PASSWORD :'accommodation_password';
CREATE ROLE holidays_booking LOGIN PASSWORD :'booking_password';
CREATE ROLE holidays_payment LOGIN PASSWORD :'payment_password';
CREATE DATABASE holidays_gateway OWNER holidays_gateway;
CREATE DATABASE holidays_accommodation OWNER holidays_accommodation;
CREATE DATABASE holidays_booking OWNER holidays_booking;
CREATE DATABASE holidays_payment OWNER holidays_payment;
SQL
