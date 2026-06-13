#!/bin/bash
set -euo pipefail

WORKSPACE="/workspaces/tp-cd-github-flow"
NETWORK="tp-cd-github-flow_cd-network"

echo "==> Démarrage des registres locaux (Verdaccio + registry:2)..."
docker compose -f "$WORKSPACE/docker-compose.yml" up -d --build

echo "==> Connexion du DevContainer au réseau Docker cd-network..."
docker network connect "$NETWORK" "$(hostname)" 2>/dev/null || true

echo "==> Démarrage des relais socat (localhost → registres Docker)..."
DEVCONTAINER_ID="$(hostname)"
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:4873" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:5000" 2>/dev/null || true
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:4873,fork,reuseaddr TCP:verdaccio:4873
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:5000,fork,reuseaddr TCP:registry:5000

echo "==> Attente du démarrage de Verdaccio..."
until curl -sf http://localhost:4873/-/ping > /dev/null 2>&1; do
  echo "   ... Verdaccio pas encore prêt, attente 2s..."
  sleep 2
done

echo "==> Attente du démarrage du registry Docker..."
until curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; do
  echo "   ... registry:2 pas encore prêt, attente 2s..."
  sleep 2
done
