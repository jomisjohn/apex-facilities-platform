"""Create Streamlit secrets from container environment without logging them."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


ALIAS_PATTERN = re.compile(r"^[a-z0-9]{8,24}$")


def required(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise ValueError(f"Required deployment setting {name} is missing.")
    return value


def toml_string(value: str) -> str:
    # JSON string escaping is compatible with TOML basic strings and covers all
    # control characters without constructing or logging a command line secret.
    return json.dumps(value, ensure_ascii=False)


def main() -> int:
    alias = required("APEX_PREVIEW_ALIAS")
    if not ALIAS_PATTERN.fullmatch(alias):
        raise ValueError("APEX_PREVIEW_ALIAS must contain 8-24 lowercase letters or numbers.")

    values = {
        "host": required("APEX_DB_HOST"),
        "port": required("APEX_DB_PORT"),
        "database": required("APEX_DB_NAME"),
        "username": f"apex_u_{alias}",
        "password": required("APEX_PREVIEW_PASSWORD"),
        "workspace": f"ws_aida1145_{alias}",
    }
    secrets_directory = Path("/app/.streamlit")
    secrets_directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    secrets_path = secrets_directory / "secrets.toml"
    secrets_text = "\n".join(
        [
            "[connections.apex]",
            'dialect = "postgresql"',
            'driver = "psycopg"',
            f"host = {toml_string(values['host'])}",
            f"port = {int(values['port'])}",
            f"database = {toml_string(values['database'])}",
            f"username = {toml_string(values['username'])}",
            f"password = {toml_string(values['password'])}",
            "",
            "[connections.apex.create_engine_kwargs]",
            "pool_pre_ping = true",
            "pool_recycle = 1800",
            "",
            "[apex]",
            f"workspace_schema = {toml_string(values['workspace'])}",
            "",
        ]
    )
    secrets_path.write_text(secrets_text, encoding="utf-8")
    secrets_path.chmod(0o600)

    os.execvp(
        "streamlit",
        [
            "streamlit",
            "run",
            "/app/streamlit_app.py",
            "--server.address=0.0.0.0",
            "--server.port=8501",
            "--server.headless=true",
        ],
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Application startup failed: {error}", file=sys.stderr)
        sys.exit(1)
