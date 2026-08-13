# Production deployment template

This public template runs the fictional Apex AIDA 1145 preview application behind automatic HTTPS. It contains no host address, account identifier or credential.

Only the web proxy publishes host ports. PostgreSQL stays on an internal Docker network and is not reachable directly from the internet in this initial configuration.

Caddy's automatic HTTPS protects browser traffic to the preview application only. It does not configure PostgreSQL TLS. Direct student database access is intentionally outside this template and must not be enabled by publishing port 5432 alone.

## Before starting

1. Install current Docker Engine with the Compose plugin on the Linux VPS.
2. Point the chosen DNS name at the VPS and allow inbound TCP ports 80 and 443. Allow UDP 443 when HTTP/3 is desired.
3. Clone this repository.
4. Copy `.env.production.example` to `.env.production` and replace every placeholder with unique values.
5. Keep `.env.production` readable only by the deployment account and never commit it.

The preview alias must contain 8-24 lowercase letters or numbers and must not be a name, email or student ID. Use different passwords for the database administrator and preview login.

## Validate and start

From the repository root:

```sh
docker compose --env-file .env.production -f deploy/compose.production.yaml config --quiet
docker compose --env-file .env.production -f deploy/compose.production.yaml up --build -d
docker compose --env-file .env.production -f deploy/compose.production.yaml ps
```

The migration service verifies SHA-256 checksums before applying new migrations. The preview provisioner idempotently creates one non-admin AIDA 1145 workspace. The application generates its ignored Streamlit secrets file inside the container at startup without printing credentials.

Do not add a PostgreSQL `ports` mapping until remote database access, firewall rules, TLS, monitoring and student-account operations have been separately approved and tested.

If remote PostgreSQL access is approved later, use PostgreSQL's native TLS with a certificate whose hostname matches the database DNS name. Require TLS in `pg_hba.conf`, keep the server private key restricted to the PostgreSQL process, and provide students with a trusted root certificate and a `verify-full` connection setting. Test DBeaver and Python connections from outside the server before releasing credentials.
