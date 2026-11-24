# Holidays Docker deployment

The Dockerfiles and Compose configuration are in the repository root.

## Prepare local secrets

Copy the example file and replace every placeholder with a different random value:

```bash
cp .env.docker.example .env.docker
openssl rand -hex 24
```

Keep `.env.docker` private. Do not commit it.

## Validate and start

```bash
docker compose --env-file .env.docker config
docker compose --env-file .env.docker up -d --build
docker compose --env-file .env.docker ps
```

Open http://localhost:8080. Only the API Gateway is published to the host. Internal services and PostgreSQL communicate over the Compose network using service DNS names.

## Troubleshoot

```bash
docker compose --env-file .env.docker logs -f
docker compose --env-file .env.docker logs -f api-gateway
docker compose --env-file .env.docker ps
docker network ls
docker volume ls
```

Health endpoints:
- Gateway: `http://localhost:8080/api/health`
- Accommodation: `http://accommodation-service:8081/health` (inside the Docker network)
- Booking: `http://booking-service:8082/health` (inside the Docker network)
- Payment: `http://payment-service:8083/health` (inside the Docker network)

## Stop

```bash
docker compose --env-file .env.docker down
```

To delete the local PostgreSQL data volume too (destructive):

```bash
docker compose --env-file .env.docker down -v
```

The PostgreSQL initialization script runs only when the data volume is first initialized. Changing passwords in the env file does not change passwords already stored in an existing database volume.

The payment service is a demo simulation only; it does not charge money or process real card details.
