#!/bin/bash
set -e
echo "🔁 Updating containers..."
docker compose pull
docker compose up -d
echo "Updated successfully."