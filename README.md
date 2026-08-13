# Apex Facilities Platform

Apex is a fictional, AI- and data-analytics-enabled facilities maintenance management platform for Fall 2026 course labs and final projects.

Maintained by **STEM AI Studio** for educational use.

This repository is the source of truth for the shared learning platform. Development and testing happen locally. Only tagged, tested releases are deployed to the Hostinger VPS.

## First milestone

1. Start one local PostgreSQL/PostGIS database.
2. Establish the 12 read-only shared domain schemas.
3. Design and validate one course's ten lab data packages.
4. Add course-scoped student workspace provisioning.
5. Deploy the tested pilot to Hostinger.

No course content, student submissions, credentials, or production-system materials belong in this repository.

## Local start

1. Copy `.env.example` to `.env` and replace the development password.
2. From Windows PowerShell, run `scripts\start_local.ps1`.
3. The helper starts the supported Docker Desktop WSL2 backend, starts the database, and runs validation.
4. Use `scripts\stop_local.ps1` when the local database is no longer needed.
5. After infrastructure changes, also run `scripts\test_container_stability.ps1` and `scripts\test_backup_restore.ps1`.

Docker Desktop runs the supported WSL2 backend. The local database listens only on `127.0.0.1:5432` and is reachable from Windows DBeaver.
