#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${POULPOINTS_BACKUP_DIR:?Set a private backup destination outside the source repository}"
: "${PGDATABASE:?Set PGDATABASE via a private connection configuration}"
mkdir -p "$POULPOINTS_BACKUP_DIR"
chmod 700 "$POULPOINTS_BACKUP_DIR"
folder=$(mktemp -d "$POULPOINTS_BACKUP_DIR/backup-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
# Credentials come from libpq environment/service/pgpass, never command arguments.
# A full dump preserves tables, tombstones, policies, functions and auth records.
pg_dump --format=custom --file="$folder/database.dump.partial"
pg_restore --list "$folder/database.dump.partial" > "$folder/contents.txt"
mv "$folder/database.dump.partial" "$folder/database.dump"
(cd "$folder" && sha256sum database.dump > SHA256SUMS)
printf '%s\n' 'Complete logical database backup. No Storage object files or project settings included.' > "$folder/README.txt"
printf '%s\n' "$folder"
