CREATE EXTENSION IF NOT EXISTS postgis;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apex_shared_reader') THEN
        CREATE ROLE apex_shared_reader NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apex_workspace_member') THEN
        CREATE ROLE apex_workspace_member NOLOGIN;
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS shared_facilities;
CREATE SCHEMA IF NOT EXISTS shared_crm;
CREATE SCHEMA IF NOT EXISTS shared_readiness;
CREATE SCHEMA IF NOT EXISTS shared_operations;
CREATE SCHEMA IF NOT EXISTS shared_workforce;
CREATE SCHEMA IF NOT EXISTS shared_quality;
CREATE SCHEMA IF NOT EXISTS shared_assets;
CREATE SCHEMA IF NOT EXISTS shared_supply;
CREATE SCHEMA IF NOT EXISTS shared_finance;
CREATE SCHEMA IF NOT EXISTS shared_insights;
CREATE SCHEMA IF NOT EXISTS shared_spatial;
CREATE SCHEMA IF NOT EXISTS shared_research;

REVOKE ALL ON SCHEMA
    shared_facilities,
    shared_crm,
    shared_readiness,
    shared_operations,
    shared_workforce,
    shared_quality,
    shared_assets,
    shared_supply,
    shared_finance,
    shared_insights,
    shared_spatial,
    shared_research
FROM PUBLIC;

GRANT USAGE ON SCHEMA
    shared_facilities,
    shared_crm,
    shared_readiness,
    shared_operations,
    shared_workforce,
    shared_quality,
    shared_assets,
    shared_supply,
    shared_finance,
    shared_insights,
    shared_spatial,
    shared_research
TO apex_shared_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA
    shared_facilities,
    shared_crm,
    shared_readiness,
    shared_operations,
    shared_workforce,
    shared_quality,
    shared_assets,
    shared_supply,
    shared_finance,
    shared_insights,
    shared_spatial,
    shared_research
GRANT SELECT ON TABLES TO apex_shared_reader;

