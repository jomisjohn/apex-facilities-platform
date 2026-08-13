import streamlit as st


st.title("AIDA 1145 Apex workspace")
st.write(
    "Build data-engineering skills with the fictional Apex Facilities Platform. Explore approved "
    "shared data, then keep your course-created tables and outputs in your assigned workspace."
)
st.subheader("Start here")
st.markdown(
    """
1. Open **Connection & workspace** and confirm your access.
2. Use **Data explorer** to understand approved shared views.
3. Review **Lab catalogue** and the page for your current lab.
4. Follow the official lab instructions for assessed work and submission.
"""
)
st.caption("Never enter a database password into a page. Credentials belong only in your local secrets file.")

