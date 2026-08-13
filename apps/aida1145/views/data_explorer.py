import streamlit as st

from apex_app.db import EXPLORER_VIEWS, explore_view
from apex_app.ui import render_connection_help


st.title("Approved data explorer")
st.write("Choose a reviewed shared view. The explorer limits results to 250 rows and does not run arbitrary SQL.")
selection = st.selectbox("Shared view", list(EXPLORER_VIEWS))

if st.button("Load data", type="primary"):
    try:
        data = explore_view(selection)
    except Exception as error:
        render_connection_help(error)
    else:
        st.dataframe(data, use_container_width=True, hide_index=True)
        st.caption(f"Displayed {len(data):,} rows. Shared reads use a bounded five-minute cache.")

