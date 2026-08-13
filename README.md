# Apex Facilities Platform

Welcome to Apex, a fictional facilities maintenance management platform where you will learn to work with professional data, analytics, AI and geospatial tools.

Maintained by **STEM AI Studio** for educational use.

## What you will build

Across your course labs, you will gradually add analysis, visualizations and application features to a portfolio-ready Streamlit project. Apex connects realistic facilities data across clients, service readiness, schedules, costs, inspections, assets, maintenance, customer insights and research.

You will work with synthetic or properly licensed open data. This repository never contains real customer information, student grades or student submissions.

## Free tools

Your course instructions will identify the tools required for each lab. The shared platform supports:

- Visual Studio Code
- Git and GitHub
- Python and Streamlit
- DBeaver Community
- PostgreSQL and PostGIS
- Docker Desktop for the optional local database

You are not required to purchase DBeaver or another database client.

## Start the optional local database

Your instructor may provide a hosted, read-only database connection. Use the local database only when your course or lab instructions ask for it.

1. Install Docker Desktop on Windows and use its WSL2 backend.
2. Copy `.env.example` to `.env`.
3. Replace the example development password in `.env` with your own local password.
4. Open Windows PowerShell in this repository.
5. Run `scripts\start_local.ps1`.
6. Connect DBeaver to `127.0.0.1`, port `5432`, database `apex_facilities`.
7. When finished, run `scripts\stop_local.ps1`.

Never commit your `.env` file or password. If the database is unavailable, follow the CSV/Parquet fallback supplied with your lab.

## How Apex data is organized

Read [How the Apex data platform works](docs/architecture.md) for the connected business domains and workspace model. Course-specific application folders and instructions will be added as each course package is released.

## Your work and ideas

You retain ownership of your original student work under your institution's policies. Do not place grades, feedback, personal information or another student's work in this repository.

## Getting help

Start with your course's lab instructions and troubleshooting section. When reporting a technical problem, include the lab number, the exact error message and the validation step that failed. Never include passwords or connection secrets.
