import streamlit as st

from apex_app.db import check_connection_and_workspace
from apex_app.ui import render_connection_help, require_workspace


st.title("Connection & workspace check")
schema = require_workspace()

if st.button("Run fresh access check", type="primary"):
    try:
        result = check_connection_and_workspace(schema)
    except Exception as error:
        render_connection_help(error)
    else:
        row = result.iloc[0]
        checks = {
            "Connected to apex_facilities": row["database_name"] == "apex_facilities",
            "Shared data is available": bool(row["can_use_shared_data"]),
            "Assigned workspace is available": bool(row["can_use_workspace"]),
            "Workspace allows table creation": bool(row["can_create_in_workspace"]),
        }
        st.write(f"Database user: `{row['database_user']}`")
        st.write(f"Workspace: `{row['workspace_schema']}`")
        for label, passed in checks.items():
            st.success(f"Passed: {label}") if passed else st.error(f"Needs attention: {label}")

st.caption("This check uses uncached results so workspace changes are visible immediately.")

