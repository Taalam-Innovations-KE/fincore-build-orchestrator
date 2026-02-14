#!/bin/bash
set -euo pipefail

export PGPASSWORD="${POSTGRES_PASSWORD}"

# Use psql variables + format(%I, %L) to safely quote identifiers/passwords.
psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" \
  -v kc_user="${KEYCLOAK_DB_USER}" \
  -v kc_pass="${KEYCLOAK_DB_PASS}" \
  -v kc_db="${KEYCLOAK_DB_NAME}" \
  -v fa_user="${FINERACT_DB_USER}" \
  -v fa_pass="${FINERACT_DB_PASS}" \
  -v fa_tenants_db="${FINERACT_TENANTS_DB_NAME}" \
  -v fa_default_db="${FINERACT_TENANT_DEFAULT_DB_NAME}" \
<<'EOSQL'

-- =========================
-- Keycloak: role + database
-- =========================
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'kc_user', :'kc_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'kc_user')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'kc_db', :'kc_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'kc_db')
\gexec

SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'kc_db', :'kc_user')
\gexec

-- =========================
-- Fineract: role + databases
-- =========================
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'fa_user', :'fa_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'fa_user')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'fa_tenants_db', :'fa_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'fa_tenants_db')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'fa_default_db', :'fa_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'fa_default_db')
\gexec

SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'fa_tenants_db', :'fa_user')
\gexec
SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'fa_default_db', :'fa_user')
\gexec

EOSQL

# Schema grants must be done after connecting to each DB
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${KEYCLOAK_DB_NAME}" <<EOSQL
  GRANT ALL ON SCHEMA public TO "${KEYCLOAK_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES    TO "${KEYCLOAK_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${KEYCLOAK_DB_USER}";
EOSQL

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${FINERACT_TENANTS_DB_NAME}" <<EOSQL
  GRANT ALL ON SCHEMA public TO "${FINERACT_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES    TO "${FINERACT_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${FINERACT_DB_USER}";
EOSQL

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${FINERACT_TENANT_DEFAULT_DB_NAME}" <<EOSQL
  GRANT ALL ON SCHEMA public TO "${FINERACT_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES    TO "${FINERACT_DB_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${FINERACT_DB_USER}";
EOSQL
