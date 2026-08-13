import re

import streamlit as st


COURSE_CODE = "AIDA 1145"
READ_TTL = "5m"
WORKSPACE_PREFIX = "ws_aida1145_"
WORKSPACE_PATTERN = re.compile(r"^ws_aida1145_[a-z0-9]{8,24}$")


def workspace_schema() -> str:
    """Return the configured course workspace after strict identifier validation."""
    try:
        schema = str(st.secrets["apex"]["workspace_schema"]).strip()
    except (FileNotFoundError, KeyError):
        return ""
    return schema if WORKSPACE_PATTERN.fullmatch(schema) else ""


def workspace_configuration_error() -> str | None:
    """Explain a missing or unsafe workspace identifier."""
    try:
        supplied = str(st.secrets["apex"]["workspace_schema"]).strip()
    except (FileNotFoundError, KeyError):
        return "Add your assigned workspace schema under [apex] in .streamlit/secrets.toml."
    if not WORKSPACE_PATTERN.fullmatch(supplied):
        return (
            f"Workspace schema must begin with `{WORKSPACE_PREFIX}` and contain only "
            "8 to 24 lowercase letters or numbers after the prefix."
        )
    return None
