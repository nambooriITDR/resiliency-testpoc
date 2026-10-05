#!/bin/bash
set -e

docker compose exec -T postgres pg_dump -U pocuser pocdb -f /tmp/pgdump.sql
docker compose run --rm restic backup /tmp/pgdump.sql /app_files
