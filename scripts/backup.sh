#!/bin/bash
set -e
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
echo "Dumping Postgres data to $BACKUP_FILE ..."
docker exec -t $(docker ps -qf "name=postgres") pg_dumpall -U postgres > $BACKUP_FILE
echo "Backup created: $BACKUP_FILE"