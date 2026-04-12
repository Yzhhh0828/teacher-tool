#!/bin/bash
set -e

BACKUP_DIR=/backups
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE=${BACKUP_DIR}/backup_${DATE}.sql

mkdir -p $BACKUP_DIR

echo "Starting backup..."

# Backup PostgreSQL
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h postgres -U $POSTGRES_USER $POSTGRES_DB > $BACKUP_FILE

# Compress
gzip $BACKUP_FILE

# Keep only last 7 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
