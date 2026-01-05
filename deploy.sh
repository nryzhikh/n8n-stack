#!/bin/bash
# -----------------------------------------------------------------------------
# n8n-stack Management Script (single-server simplified)
# -----------------------------------------------------------------------------

set -e

# === CONFIGURATION ============================================================
STACK_NAME="n8n-stack"
POSTGRES_CONTAINER="${STACK_NAME}-postgres-1"
BACKUP_DIR="./backups"
ENV_FILE=".env"

# Remote server
REMOTE_USER="deploy"
# REMOTE_HOST="165.232.125.58"
REMOTE_HOST="89.191.234.118"
REMOTE_PATH="/home/deploy/n8n-stack"
# ==============================================================================

mkdir -p "$BACKUP_DIR"

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  up               Start or update docker-compose
  down             Stop and remove containers
  rebuild          Rebuild and restart containers
  logs <service>   Tail logs for a given service
  backup           Dump Postgres DB to ./backups
  restore <file>   Restore DB from SQL file
  prune            Cleanup unused Docker data
  push             Upload local repo to remote server via rsync
  sync-env         Upload local .env file to remote server
  restart          Restart the Docker stack on the remote server
  pull             Download latest remote DB backup
  remote-backup    Run backup remotely and pull it locally
  help             Show this help message
EOF
}

# === CORE FUNCTIONS ===========================================================

backup_db() {
  local ts
  ts=$(date +%Y%m%d_%H%M%S)
  local outfile="${BACKUP_DIR}/n8n_${ts}.sql"
  echo "Creating local backup: $outfile"
  docker exec -t "$POSTGRES_CONTAINER" pg_dump -U postgres n8n > "$outfile"
  echo "Backup complete: $outfile"
}

backup_remote() {
  echo "Creating remote backup and downloading it..."
  echo "ssh ${REMOTE_USER}@${REMOTE_HOST} \"cd ${REMOTE_PATH} && ./deploy.sh backup\""
  ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && ./deploy.sh backup"
  ./deploy.sh pull
  echo "Remote backup complete and copied locally."
}

pull_backup() {
  echo "Fetching latest backup from remote..."
  local latest_file
  latest_file=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "ls -t ${REMOTE_PATH}/backups/n8n_*.sql 2>/dev/null | head -n 1")
  if [ -z "$latest_file" ]; then
    echo "No backups found on remote."
    exit 1
  fi
  scp ${REMOTE_USER}@${REMOTE_HOST}:"$latest_file" ./backups/
  echo "Pulled $(basename "$latest_file") into ./backups/"
}

restore_db() {
  local infile="${1:-}"
  if [ -z "$infile" ]; then
    echo "Error: specify a file to restore."
    exit 1
  fi
  if [ ! -f "$infile" ]; then
    echo "Error: file not found: $infile"
    exit 1
  fi
  echo "Restoring database from $infile ..."
  cat "$infile" | docker exec -i "$POSTGRES_CONTAINER" psql -U n8n -d n8n
  echo "Restore complete."
}

push_repo() {
  echo "Syncing repository to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
  rsync -az --delete \
    --exclude 'postgres_data/' \
    --exclude 'n8n_data/' \
    --exclude 'nocodb_data/' \
    --exclude 'caddy_data/' \
    --exclude 'backups/' \
    --exclude '.git/' \
    ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/
  echo "Repository sync complete."
}

sync_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    echo "No .env file found locally."
    exit 1
  fi
  echo "Uploading .env to remote server..."
  scp "${ENV_FILE}" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/.env
  echo ".env file uploaded successfully."
}

restart_stack() {
  echo "Restarting stack on remote server..."
  ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose down && docker compose up -d"
  echo "Stack restarted successfully."
}


# === DOCKER SHORTCUTS =========================================================
up()        { docker compose up -d; }
down()      { docker compose down; }
rebuild()   { docker compose down && docker compose build --no-cache && docker compose up -d; }
logs()      { docker logs -f "${STACK_NAME}-$1-1"; }
prune()     { docker system prune -f --volumes; }

# === COMMAND HANDLER ==========================================================
case "${1:-}" in
  up)              up ;;
  down)            down ;;
  rebuild)         rebuild ;;
  logs)            logs "${2:-}" ;;
  backup)          backup_db ;;
  backup_remote)   backup_remote ;;
  restore)         restore_db "${2:-}" ;;
  prune)           prune ;;
  push)            push_repo ;;
  pull)            pull_backup ;;
  sync-env)        sync_env ;;
  restart)         restart_stack ;;
  help|--help|-h|"") usage ;;
  *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
