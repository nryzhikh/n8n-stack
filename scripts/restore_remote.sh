#!/bin/bash
set -e

# Configuration
SERVER="deploy@89.191.234.118"
POSTGRES_USER="postgres"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../backups"

# Check if backup file provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -10 || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
BACKUP_NAME=$(basename "$BACKUP_FILE")

echo "⚠️  WARNING: DATABASE RESTORE"
echo "═══════════════════════════════════════════"
echo "Server: $SERVER"
echo "Backup: $BACKUP_NAME"
echo "Size: $BACKUP_SIZE"
echo ""
echo "This will:"
echo "1. Stop all services"
echo "2. Restore PostgreSQL"
echo "3. Start all services"
echo ""
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🔄 Starting restore process..."

# Upload backup to server first
echo "📤 Uploading backup to server..."
REMOTE_BACKUP="/tmp/restore_$(date +%s).sql.gz"
scp "$BACKUP_FILE" "$SERVER:$REMOTE_BACKUP"

echo "⏸️  Stopping all services..."
ssh "$SERVER" "cd ~/n8n-stack && docker compose down"

echo "🔄 Starting only PostgreSQL..."
ssh "$SERVER" "cd ~/n8n-stack && docker compose up -d postgres"

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

echo "📦 Restoring database..."
ssh "$SERVER" << EOF
    set -e
    echo "Decompressing and restoring..."
    gunzip -c "$REMOTE_BACKUP" | docker exec -i n8n-stack-postgres-1 psql -U $POSTGRES_USER
    
    echo "Cleaning up..."
    rm -f "$REMOTE_BACKUP"
EOF

if [ $? -ne 0 ]; then
    echo "❌ Restore failed!"
    echo "Starting services anyway..."
    ssh "$SERVER" "cd ~/n8n-stack && docker compose up -d"
    exit 1
fi

echo "✅ Database restored!"
echo "🔄 Starting all services..."
ssh "$SERVER" "cd ~/n8n-stack && docker compose up -d"

echo "⏳ Waiting for services to start..."
sleep 10

echo ""
echo "✅ Restore completed successfully!"
echo ""
echo "Services should be available at:"
echo "  - n8n: https://n8n.nryzhikh.dev"
echo "  - nocodb: https://nocodb.nryzhikh.dev"
echo "  - rsshub: https://rsshub.nryzhikh.dev"
echo ""
echo "Check status: ssh $SERVER 'cd ~/n8n-stack && docker compose ps'"