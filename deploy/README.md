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

## Gated native PostgreSQL TLS option

The optional `compose.database-tls.yaml` overlay is disabled unless it is explicitly included. It enables PostgreSQL 17 native TLS and a fail-closed authentication file:

- TCP access is accepted only through `hostssl`.
- Only provisioned members of `apex_workspace_member` may connect remotely to `apex_facilities`.
- Database-administrator automation uses a password-protected Unix socket shared only with the migration and provisioning services.
- The Streamlit application continues using the internal Docker service name and requires encrypted PostgreSQL transport.
- The safe default host bind is `127.0.0.1`; this is not direct internet access.

Supply a CA-issued certificate outside the repository in the directory named by `APEX_DB_TLS_SOURCE_DIR`. The directory must contain:

- `fullchain.pem`, beginning with the database server certificate and including required intermediate certificates.
- `privkey.pem`, the matching unencrypted private key.

The preparation service checks expiry, hostname identity and key matching, then atomically copies the files into a dedicated Docker volume. PostgreSQL receives a `0600` private key owned by its runtime account. Certificate paths and keys never enter the image or repository.

### ACME webroot issuance and renewal

The optional `compose.database-acme.yaml` integration uses the official Certbot 5.7 image and remains separate from Caddy's internal certificate storage. Caddy serves only `/.well-known/acme-challenge/` for the database hostname over HTTP port 80; the explicit HTTP site does not enable Caddy-managed TLS for that hostname. Certbot retains its account and renewal state in private Docker volumes and atomically exports only `fullchain.pem` and `privkey.pem` to `APEX_DB_TLS_SOURCE_DIR`.

Start the base web stack first, confirm the database hostname resolves to the VPS and TCP 80 reaches Caddy, then issue the certificate:

```sh
deploy/database/manage-db-certificate.sh issue .env.production
```

Issuance does not publish PostgreSQL. Afterward, validate the native-TLS overlay and continue only through the release gates below.

Render the gated configuration without starting it:

```sh
docker compose --env-file .env.production \
  -f deploy/compose.production.yaml \
  -f deploy/compose.database-tls.yaml \
  config --quiet
```

Schedule `deploy/database/manage-db-certificate.sh renew .env.production` daily with the VPS scheduler or a systemd timer. Certbot's successful-renewal deploy hook exports a replacement only after renewal. The wrapper then revalidates and atomically refreshes the PostgreSQL TLS volume, sends PostgreSQL `SIGHUP`, and confirms readiness. A no-renewal run safely revalidates and reloads the current material. Do not scrape Caddy's storage: Caddy manages web certificates, while Certbot manages the separate PostgreSQL lineage. PostgreSQL 17 rereads its certificate and key during reload; an invalid replacement is rejected while the previous working TLS configuration remains active.

For the standard production checkout at `/opt/apex-facilities-platform`, install the included persistent daily systemd timer after the renewal dry run and reload rehearsal pass:

```sh
deploy/systemd/install-certificate-renewal.sh
systemctl status --no-pager apex-db-certificate-renew.timer
systemctl list-timers --all apex-db-certificate-renew.timer
```

The installer immediately runs one renewal/reload check and fails if that service fails. Subsequent runs are recorded in the system journal; inspect `journalctl -u apex-db-certificate-renew.service` during routine operations and after any monitoring alert. A different repository location requires reviewed unit paths rather than an undocumented symlink or copied script.

Before scheduling it, rehearse Certbot renewal using the CA staging/dry-run pathway and the complete PostgreSQL reload test. Monitor scheduler failures and certificate expiry; unmonitored automation does not satisfy the release gate.

Do not change `APEX_DB_BIND_ADDRESS` from `127.0.0.1` or open a firewall port during this preparation phase. Internet release requires all of the following evidence:

1. The database DNS name resolves correctly and matches the certificate SAN.
2. The VPS firewall allows only the intended port and connection monitoring/rate controls are active.
3. A non-TLS connection is rejected.
4. The administrator login is rejected over TCP.
5. A provisioned student login succeeds with `sslmode=verify-full` and a trusted CA root.
6. DBeaver Community and Python are tested from the campus network and a separate external network.
7. Certificate renewal and PostgreSQL reload are rehearsed without losing existing connections.
8. Class-wide simultaneous-login and representative query load tests establish measured per-student connection limits, bounded application pool settings, administrator connection reserve/capacity, and VPS resource headroom. Do not guess these thresholds.
9. Docker-aware host firewall and connection-rate controls are implemented and tested against the actual published container port; a host firewall rule that Docker bypasses does not satisfy this gate.

### Required remote client settings

For DBeaver Community, create a PostgreSQL connection using the assigned database hostname, port, database, non-admin username and password. In the SSL settings, select **verify-full** and provide the trusted root CA file when the workstation does not already trust the issuing CA. The connection must use the hostname, not a raw IP address. Never accept an untrusted certificate or use `require` as a substitute for hostname verification.

For Python with psycopg, use separate secret values and require hostname verification:

```python
import psycopg

connection = psycopg.connect(
    host="YOUR_ASSIGNED_DATABASE_HOST",
    port=5432,
    dbname="apex_facilities",
    user="YOUR_ASSIGNED_DATABASE_USER",
    password="YOUR_ASSIGNED_DATABASE_PASSWORD",
    sslmode="verify-full",
    sslrootcert="PATH_TO_TRUSTED_ROOT_CA",
)
```

Keep connection secrets outside Python source, notebooks and Git. The actual deployment hostname and assigned credentials are distributed privately, not through this public repository.

Test outbound port 5432 from the campus network before releasing this pathway. If the campus blocks it, do not weaken `sslmode`, accept an invalid certificate, or move PostgreSQL onto an HTTPS port without a separately designed and tested protocol gateway. Use the approved CSV/Parquet fallback only for a lab that does not assess database behaviour. For outcomes requiring database joins, constraints, transactions, permissions, workspace writes or live persistence, use the tested local Docker route or another institutionally supervised network pathway.
