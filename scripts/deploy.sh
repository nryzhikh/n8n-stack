#!/bin/bash
set -e
echo "Deploying n8n-stack..."
git pull || true
docker compose pull
docker compose up -d
docker system prune -f
echo "Deployment complete."