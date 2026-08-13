from streamlit.testing.v1 import AppTest


def test_home_page_starts_with_student_context(app_root) -> None:
    app = AppTest.from_file(app_root / "streamlit_app.py", default_timeout=15)
    app.run()

    assert not app.exception
    visible_text = " ".join(str(element.value) for element in [*app.info, *app.title, *app.markdown])
    assert "Synthetic learning data" in visible_text
    assert "AIDA 1145" in visible_text
    assert "Shared Apex schemas are read-only" in visible_text
