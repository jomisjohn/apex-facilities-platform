import streamlit as st

from apex_app.catalogue import LABS
from apex_app.db import load_lab_catalogue
from apex_app.ui import render_connection_help


st.title("AIDA 1145 lab catalogue")
st.write("These entries describe approved learning packages. Your official lab instructions contain the assessed requirements.")

try:
    catalogue = load_lab_catalogue()
except Exception as error:
    render_connection_help(error)
    st.subheader("Approved package titles")
    for number, (title, purpose) in LABS.items():
        st.markdown(f"**Lab {number:02d}: {title}**  \n{purpose}")
else:
    st.dataframe(catalogue, use_container_width=True, hide_index=True)
    st.caption("Package metadata uses a bounded five-minute cache.")

