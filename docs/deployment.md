# Development and deployment workflow

## Source of truth

The local Git repository is the source of truth. A private GitHub repository will provide version history and off-device backup after the local scaffold is validated.

## Environments

1. **Local development:** PostgreSQL/PostGIS runs through Docker Compose and listens only on localhost.
2. **Pilot:** A clean local rebuild validates migrations, seed data, permissions, backup and restore.
3. **Hostinger staging:** Deploy a tagged release with VPS-only secrets and test remote connectivity.
4. **Hostinger teaching:** Promote the tested release after institutional approval, network testing and recovery testing.

## Rules

- Do not edit application or database definitions directly on the VPS.
- Do not commit `.env`, passwords, private keys, student rosters, database dumps or raw restricted data.
- Database changes use ordered, repeatable migrations.
- Deployment uses tagged releases rather than an unversioned working branch.
- Back up before every migration and test restoration before student use.
- Keep a CSV/Parquet course fallback for network outages.

## Deliberately deferred

- Public exposure of PostgreSQL port 5432
- TLS certificates and firewall rules
- Student account provisioning
- Connection pooling
- Streamlit application shell
- Production monitoring and automated backups
- GitHub remote creation

These are implemented only after the local database foundation and first-course data model are approved.

## Local Docker runtime

Docker Desktop 4.86.0 with its supported WSL2 backend is the Windows development runtime. Docker Engine and CLI packages installed directly inside Ubuntu were removed to avoid the conflict identified by Docker's WSL2 documentation. Use the Windows Docker CLI and the repository PowerShell helpers. The local database must pass `scripts\validate_database.ps1`, `scripts\test_container_stability.ps1`, and `scripts\test_backup_restore.ps1` after infrastructure changes.

PostgreSQL remains bound to `127.0.0.1:5432`; Windows DBeaver connectivity is tested without exposing the local service to the LAN.

## Verified foundation

- PostgreSQL 17.5 and PostGIS 3.5.2 start successfully.
- All 12 shared schemas and both NOLOGIN group roles initialize successfully.
- Password-authenticated TCP works.
- The shared-reader role can select but cannot insert or create shared objects.
- The container and persistent volume survive a complete Docker Desktop stop, WSL shutdown and Docker Desktop restart.
- The container remains continuously healthy with no restart-count change during the stability test.
- A custom-format database backup restores successfully with all 12 shared schemas.

## Installed workstation tools

- Git 2.53.0
- GitHub CLI 2.97.0
- DBeaver Community 26.1.4
- Docker Desktop 4.86.0 / Docker Engine 29.7.2

GitHub publication is pending user authentication and repository-specific Git author name/email. Do not invent or copy identity settings from an unrelated project.
