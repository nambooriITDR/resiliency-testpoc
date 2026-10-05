#!/bin/bash
set -e

SNAPSHOT=${1:-latest}
docker compose run --rm restic restore "$SNAPSHOT" --target /tmp/restore
RESTORE_SQL="/tmp/restore/tmp/pgdump.sql"
if [ ! -f "$RESTORE_SQL" ]; then
  RESTORE_SQL="/tmp/restore/pgdump.sql"
fi
if [ ! -f "$RESTORE_SQL" ]; then
  echo "Database dump not found in restored snapshot" >&2
  exit 1
fi
docker compose exec -T postgres psql -U pocuser -d pocdb -f "$RESTORE_SQL"
