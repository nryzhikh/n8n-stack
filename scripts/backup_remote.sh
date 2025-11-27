#!/bin/bash
set -e

# Configuration
SERVER="deploy@165.232.125.58"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$REPO_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Connecting to server: $SERVER"
echo "Creating PostgreSQL backup..."

# SSH to server and stream the backup to local file
ssh "$SERVER" "docker exec -t n8n-stack-postgres-1 pg_dumpall -c -U postgres" > "$BACKUP_FILE"

# Check if backup was successful
if [ -s "$BACKUP_FILE" ]; then
    # Compress the backup
    echo "Compressing backup..."
    gzip "$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"
    
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup created successfully!"
    echo "Location: $BACKUP_FILE"
    echo "Size: $SIZE"
    
    # Keep only last 7 backups
    echo "🧹 Cleaning old backups (keeping last 7)..."
    ls -t "$BACKUP_DIR"/postgres_backup_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
    
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/postgres_backup_*.sql.gz 2>/dev/null || echo "No previous backups"
else
    echo "Backup failed - file is empty"
    rm -f "$BACKUP_FILE"
    exit 1
fi