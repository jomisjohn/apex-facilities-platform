# AIDA 1145 Apex student shell

This local Streamlit app helps you explore approved synthetic Apex data and build AIDA 1145 lab features in your assigned course workspace. Shared schemas are read-only. Your workspace is writable and belongs only to this course enrollment.

## Set up

1. Open a terminal in `apps/aida1145`.
2. Create and activate a Python 3.10-or-newer virtual environment.
3. Install the pinned packages with `python -m pip install -r requirements.txt`.
4. Copy `.streamlit/secrets.toml.example` to `.streamlit/secrets.toml`.
5. Enter the connection details and workspace schema supplied for your course. Do not share or commit this file.
6. Run `streamlit run streamlit_app.py`.
7. Open **Connection & workspace** first and confirm that every check passes.

The app runs on your computer. It uses one supported Streamlit SQL connection backed by SQLAlchemy; it does not cache a raw PostgreSQL connection.

## Safe use

- Use the Data explorer's approved views; it does not accept arbitrary SQL.
- Do not try to change shared schemas.
- Save lab-created tables and outputs only in your assigned AIDA 1145 workspace.
- Do not store personal information, grades, feedback, passwords or another student's work.
- Use your lab instructions as the authority for assessed requirements and submissions. The pages here provide package context, not assessment solutions.

If the connection is unavailable, use the CSV or Parquet fallback provided with the relevant lab.

