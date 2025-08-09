#!/bin/sh
set -euo pipefail

# Simple Postgres backup script used by the backup service in docker-compose.prod.yml
# Requires env: POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, BACKUP_RETENTION_DAYS

STAMP=$(date +%Y%m%d-%H%M%S)
DEST=/backups
FILE="$DEST/${POSTGRES_DB}-${STAMP}.sql.gz"

echo "[backup] Starting backup for $POSTGRES_DB to $FILE"

export PGPASSWORD="$POSTGRES_PASSWORD"
pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -F p \
  | gzip -9 > "$FILE"

echo "[backup] Wrote $(du -h "$FILE" | cut -f1) to $FILE"

# Prune old backups
find "$DEST" -type f -name "${POSTGRES_DB}-*.sql.gz" -mtime +"${BACKUP_RETENTION_DAYS}" -print -delete || true

echo "[backup] Done"


