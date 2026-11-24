# Holidays

A responsive, TUI-inspired stay discovery and demo booking application. Developed by Avinesh.

## Features
- Responsive destination search, date selection and guest selector
- Stay cards, category filters, sorting and favourites
- Stay detail modal and demo booking flow
- My Bookings page stored in browser localStorage
- Docker image served by Nginx
- Starter Kubernetes manifests

> **Important:** This is a frontend demo. It has no live hotel inventory, reservation supplier, backend, authentication or payment integration. Bookings are saved only in the current browser.

## Run locally
Requires Node.js 20+ and npm.

```bash
npm install
npm run dev
```
Open http://localhost:5173.

## Production build
```bash
npm run build
npm run preview
```

## Docker
```bash
docker build -t holidays:1.0 .
docker run --rm -p 8080:80 holidays:1.0
```
Open http://localhost:8080.

## Kubernetes
Update the image in `k8s/deployment.yaml` to your registry image, then run:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
kubectl -n holidays rollout status deployment/holidays-web
kubectl -n holidays get pods,svc,ingress
```

## Structure
- `src/App.jsx` — UI and booking interactions
- `src/style.css` — responsive styling
- `Dockerfile`, `nginx.conf` — container setup
- `k8s/` — Kubernetes starter manifests

Holidays · Developed by Avinesh · 2026