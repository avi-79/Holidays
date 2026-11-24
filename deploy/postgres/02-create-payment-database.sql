-- Run as a PostgreSQL administrator. Use a unique strong password.
CREATE ROLE holidays_payment LOGIN PASSWORD 'CHANGE_ME_PAYMENT_PASSWORD';
CREATE DATABASE holidays_payment OWNER holidays_payment;
