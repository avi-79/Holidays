-- Run as a PostgreSQL administrator. Replace the sample passwords before use.
CREATE ROLE holidays_gateway LOGIN PASSWORD 'CHANGE_ME_GATEWAY_PASSWORD';
CREATE ROLE holidays_accommodation LOGIN PASSWORD 'CHANGE_ME_ACCOMMODATION_PASSWORD';
CREATE ROLE holidays_booking LOGIN PASSWORD 'CHANGE_ME_BOOKING_PASSWORD';
CREATE DATABASE holidays_gateway OWNER holidays_gateway;
CREATE DATABASE holidays_accommodation OWNER holidays_accommodation;
CREATE DATABASE holidays_booking OWNER holidays_booking;
