-- Optional one-time migration for hosts that already created the original
-- three Holidays databases before the Payment Service was added.
-- Do NOT run this after 01-create-databases.sql unless you specifically need
-- to add the payment database to an existing three-database installation.
-- Replace CHANGE_ME_PAYMENT_PASSWORD before running as PostgreSQL admin.
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -f deploy/postgres/02-create-payment-database.sql

SELECT 'CREATE ROLE holidays_payment LOGIN PASSWORD ''CHANGE_ME_PAYMENT_PASSWORD'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'holidays_payment')\gexec
SELECT 'CREATE DATABASE holidays_payment OWNER holidays_payment'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'holidays_payment')\gexec
