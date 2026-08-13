import streamlit as st

from apex_app.config import COURSE_CODE, workspace_configuration_error, workspace_schema


def configure_page() -> None:
    st.set_page_config(page_title="AIDA 1145 | Apex", page_icon=":material/domain:", layout="wide")


def render_context_banner() -> None:
    schema = workspace_schema()
    workspace_label = f"`{schema}`" if schema else "not configured"
    st.info(
        f"**Synthetic learning data - {COURSE_CODE}**  \n"
        f"Shared Apex schemas are read-only. Active course workspace: {workspace_label}."
    )


def require_workspace() -> str:
    error = workspace_configuration_error()
    if error:
        st.error(error)
        st.stop()
    return workspace_schema()


def render_connection_help(error: Exception) -> None:
    st.error("Apex could not connect with the current local settings.")
    st.write(
        "Check `.streamlit/secrets.toml`, your internet connection and the connection details "
        "provided for your course. Restart Streamlit after changing secrets."
    )
    st.caption(f"Technical detail: {type(error).__name__}: {error}")
    st.info("If your lab provides CSV or Parquet fallback files, you can continue with that pathway.")
