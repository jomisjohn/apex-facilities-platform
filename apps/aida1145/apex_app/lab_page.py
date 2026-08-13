import streamlit as st

from apex_app.catalogue import LABS
from apex_app.config import workspace_schema


def render_lab_page(number: int) -> None:
    title, purpose = LABS[number]
    st.title(f"Lab {number:02d}: {title}")
    st.markdown(f"**Package purpose:** {purpose}")
    st.write(
        "This page identifies the approved Apex package context. Use the official lab instructions "
        "for assessed requirements, deadlines, evidence and submission steps."
    )
    st.subheader("Your working boundary")
    schema = workspace_schema()
    st.write(f"Writable course workspace: `{schema}`" if schema else "Configure your assigned workspace before beginning database work.")
    st.write("Shared Apex data is synthetic and read-only. Create lab outputs only in your assigned course workspace.")
    st.warning("This shell does not provide an assessment solution. Your implementation, evidence and explanations must be your own.")

