-- Holidays PostgreSQL bootstrap: four isolated roles and databases.
-- Run once as a PostgreSQL administrator with psql.
-- Replace each CHANGE_ME password before running this file.
-- Example:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -f deploy/postgres/01-create-databases.sql

SELECT 'CREATE ROLE holidays_gateway LOGIN PASSWORD ''CHANGE_ME_GATEWAY_PASSWORD'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'holidays_gateway')\gexec
SELECT 'CREATE ROLE holidays_accommodation LOGIN PASSWORD ''CHANGE_ME_ACCOMMODATION_PASSWORD'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'holidays_accommodation')\gexec
SELECT 'CREATE ROLE holidays_booking LOGIN PASSWORD ''CHANGE_ME_BOOKING_PASSWORD'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'holidays_booking')\gexec
SELECT 'CREATE ROLE holidays_payment LOGIN PASSWORD ''CHANGE_ME_PAYMENT_PASSWORD'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'holidays_payment')\gexec

SELECT 'CREATE DATABASE holidays_gateway OWNER holidays_gateway'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'holidays_gateway')\gexec
SELECT 'CREATE DATABASE holidays_accommodation OWNER holidays_accommodation'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'holidays_accommodation')\gexec
SELECT 'CREATE DATABASE holidays_booking OWNER holidays_booking'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'holidays_booking')\gexec
SELECT 'CREATE DATABASE holidays_payment OWNER holidays_payment'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'holidays_payment')\gexec
