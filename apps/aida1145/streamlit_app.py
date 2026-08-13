import streamlit as st

from apex_app.ui import configure_page, render_context_banner


configure_page()
render_context_banner()

pages = {
    "Apex workspace": [
        st.Page("views/home.py", title="Home", icon=":material/home:", default=True),
        st.Page(
            "views/connection_check.py",
            title="Connection & workspace",
            icon=":material/database:",
            url_path="connection",
        ),
        st.Page(
            "views/data_explorer.py",
            title="Data explorer",
            icon=":material/table_view:",
            url_path="explorer",
        ),
        st.Page(
            "views/lab_catalogue.py",
            title="Lab catalogue",
            icon=":material/menu_book:",
            url_path="labs",
        ),
    ],
    "AIDA 1145 labs": [
        st.Page(f"labs/lab_{number:02d}.py", title=f"Lab {number:02d}", url_path=f"lab-{number:02d}")
        for number in range(1, 11)
    ],
}

current_page = st.navigation(pages, position="sidebar", expanded=10)
current_page.run()

