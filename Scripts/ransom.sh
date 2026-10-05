#!/bin/bash
set -e

rm -rf app_files/*
docker compose exec -T postgres psql -U pocuser -d pocdb -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
