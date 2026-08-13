# Build the AIDA 1145 app locally

This guide is for the **AIDA 1145 Data Engineering** Streamlit shell. You build and test lab features in your own local copy. The hosted preview is a reference deployment; it is not a student-editable coding workspace.

The shell begins with ten registered lab pages. You will extend those pages incrementally as each lab is released. Follow the official lab instructions for assessed requirements and submission evidence.

## 1. Get the repository

Cloning is recommended because it preserves Git history:

```powershell
git clone https://github.com/jomisjohn/apex-facilities-platform.git
cd apex-facilities-platform/apps/aida1145
```

If Git is temporarily unavailable, download the repository ZIP from GitHub, extract it, and open `apps/aida1145` in VS Code. A ZIP copy does not include a working Git history.

## 2. Create the Python environment

From `apps/aida1145`, create a project-local environment and install the tested packages:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

On macOS or Linux, activate with `source .venv/bin/activate` instead.

## 3. Configure your private connection

Copy `.streamlit/secrets.toml.example` to `.streamlit/secrets.toml`. Replace every placeholder with the database hostname, username, password and exact AIDA 1145 workspace schema supplied to you. Never commit or share `secrets.toml`.

For the instructor-managed remote database, add the required verified TLS settings below the password:

```toml
[connections.apex.query]
sslmode = "verify-full"
sslrootcert = "C:/path/to/trusted-root-ca.pem"
connect_timeout = "10"
```

Use the assigned hostname, not a raw IP address. Do not weaken TLS or accept an untrusted certificate. If your workstation already trusts the issuing public CA, follow the connection directions supplied for your class rather than inventing a certificate path.

## 4. Run the local app

```powershell
streamlit run streamlit_app.py
```

Open the local address shown in the terminal, normally `http://localhost:8501`. Select **Connection & workspace** first and confirm that the connection, assigned schema and permissions pass.

## 5. Connect DBeaver Community

Create a PostgreSQL connection with the same assigned hostname, port, database, username and password used by your local app. In DBeaver's SSL settings, use **verify-full**. If a trusted root file is requested, download the official [ISRG Root X1 PEM from Let's Encrypt](https://letsencrypt.org/certs/isrgrootx1.pem), save it as `isrgrootx1.pem`, and select that file. Test the connection before saving it. Never switch to `require` or accept an untrusted certificate to bypass a certificate error.

DBeaver and local Streamlit use the same PostgreSQL workspace. A committed database change made in one tool becomes visible in the other after the query or page is refreshed. DBeaver Community is sufficient; no paid edition is required.

## 6. Extend an existing lab page

Open the matching file in `labs`, such as `labs/lab_01.py`. Keep the shared package context and add only the feature required by the current lab. Run Streamlit, open that page, and test normal, empty and invalid-input cases.

Shared domain schemas are read-only. Create or change tables only in the exact schema returned by the app's validated workspace configuration. Never build a schema name from unchecked user input, write to another student's workspace, or place passwords in Python files.

## 7. Register a new page safely

Do not rely on automatic discovery from a `pages` folder. This shell uses an explicit `st.Page` registry in `streamlit_app.py`.

1. Create the page as a Python file inside the course app, using a lowercase descriptive filename.
2. Add one explicit `st.Page(...)` entry to the appropriate navigation group in `streamlit_app.py`.
3. Give it a unique title and `url_path`.
4. Import shared helpers from `apex_app` instead of copying connection or workspace-validation logic.
5. Restart or rerun Streamlit and confirm the new page appears and other pages still open.

Do not add unapproved assessment solutions, arbitrary-SQL input boxes, credentials or personal information.

## 8. Save work with Git

Before editing, create a course-work branch using the naming direction provided in your lab:

```powershell
git switch -c aida1145-lab-01
git status
```

After testing, review and commit only the files you intended to change:

```powershell
git diff
git add labs/lab_01.py
git commit -m "Complete AIDA 1145 Lab 01 feature"
```

Push only to the personal or course remote specified by your instructor. Confirm that `.streamlit/secrets.toml`, data exports, personal information and credentials are absent from `git status` before every commit. D2L remains the official submission location unless the lab instructions explicitly state otherwise.
