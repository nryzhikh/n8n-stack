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
REMOTE_HOST="your.server.ip"
REMOTE_PATH="/home/deploy/n8n-stack"
# ==============================================================================

mkdir -p "$BACKUP_DIR"

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  up              Start or update docker-compose
  down            Stop and remove containers
  rebuild         Rebuild and restart containers
  logs <service>  Tail logs for given service
  backup          Dump Postgres DB to ./backups
  restore <file>  Restore DB from SQL file
  prune           Cleanup unused Docker data
  push            Upload local repo to remote server (via rsync)
  sync-env        Push local .env file to remote server and restart stack
  pull            Download latest remote DB backup
  remote-backup   Run backup remotely and pull it locally
  help            Show this help message
EOF
}

# === CORE FUNCTIONS ===========================================================

backup_db() {
  local ts
  ts=$(date +%Y%m%d_%H%M%S)
  local outfile="${BACKUP_DIR}/n8n_${ts}.sql"
  echo "📦 Creating backup: $outfile"
  docker exec -t "$POSTGRES_CONTAINER" pg_dump -U n8n n8n > "$outfile"
  echo "✅ Backup complete."
}

restore_db() {
  local infile="$1"
  if [ -z "$infile" ]; then
    echo "Error: specify a file to restore."
    exit 1
  fi
  if [ ! -f "$infile" ]; then
    echo "Error: File not found: $infile"
    exit 1
  fi
  echo "⚙️ Restoring DB from $infile ..."
  cat "$infile" | docker exec -i "$POSTGRES_CONTAINER" psql -U n8n -d n8n
  echo "✅ Restore complete."
}

pull_backup() {
  echo "📥 Fetching latest backup from remote..."
  latest_file=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "ls -t ${REMOTE_PATH}/backups/n8n_*.sql 2>/dev/null | head -n 1")
  if [ -z "$latest_file" ]; then
    echo "❌ No backups found on remote."
    exit 1
  fi
  scp ${REMOTE_USER}@${REMOTE_HOST}:"$latest_file" ./backups/
  echo "✅ Pulled $(basename "$latest_file") into ./backups/"
}

push_repo() {
  echo "🚀 Syncing repo to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
  rsync -az --delete \
    --exclude 'postgres_data/' \
    --exclude 'n8n_data/' \
    --exclude 'nocodb_data/' \
    --exclude 'caddy_data/' \
    --exclude 'backups/' \
    --exclude '.git/' \
    ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/
  echo "✅ Repo sync complete."
}

sync_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    echo "❌ No .env file found locally."
    exit 1
  fi
  echo "🔄 Uploading .env to server..."
  scp "${ENV_FILE}" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/.env
  ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose down && docker compose up -d"
  echo "✅ Environment synced and stack restarted remotely."
}

remote_backup() {
  echo "🌐 Running remote backup..."
  ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && ./manage.sh backup"
  ./manage.sh pull
  echo "✅ Remote backup pulled locally."
}

# === DOCKER SHORTCUTS =========================================================
up()        { docker compose up -d; }
down()      { docker compose down; }
rebuild()   { docker compose down && docker compose build --no-cache && docker compose up -d; }
logs()      { docker logs -f "${STACK_NAME}-$1-1"; }
prune()     { docker system prune -f --volumes; }

# === COMMAND HANDLER ==========================================================
case "$1" in
  up)              up ;;
  down)            down ;;
  rebuild)         rebuild ;;
  logs)            logs "$2" ;;
  backup)          backup_db ;;
  restore)         restore_db "$2" ;;
  prune)           prune ;;
  push)            push_repo ;;
  pull)            pull_backup ;;
  sync-env)        sync_env ;;
  remote-backup)   remote_backup ;;
  help|--help|-h|"") usage ;;
  *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
