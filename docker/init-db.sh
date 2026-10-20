#!/bin/bash
set -e

echo "==> Configuring PostgreSQL databases..."

# Cria os bancos auth_db, flags_db e targeting_db se não existirem
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE auth_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'auth_db')\gexec

    SELECT 'CREATE DATABASE flags_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'flags_db')\gexec

    SELECT 'CREATE DATABASE targeting_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'targeting_db')\gexec
EOSQL

echo "==> Applying auth-service migrations to auth_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "auth_db" -f /scripts/auth-init.sql

echo "==> Applying flag-service migrations to flags_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "flags_db" -f /scripts/flag-init.sql

echo "==> Applying targeting-service migrations to targeting_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "targeting_db" -f /scripts/targeting-init.sql

echo "==> PostgreSQL databases initialized successfully!"
