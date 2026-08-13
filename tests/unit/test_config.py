from unittest.mock import patch

from apex_app.config import workspace_configuration_error, workspace_schema


def test_valid_workspace_schema_is_returned() -> None:
    with patch("apex_app.config.st.secrets", {"apex": {"workspace_schema": "ws_aida1145_example01"}}):
        assert workspace_schema() == "ws_aida1145_example01"
        assert workspace_configuration_error() is None


def test_missing_workspace_schema_is_safe() -> None:
    with patch("apex_app.config.st.secrets", {}):
        assert workspace_schema() == ""
        assert workspace_configuration_error()


def test_unsafe_workspace_identifiers_are_rejected() -> None:
    unsafe = [
        "ws_aida1145_short",
        "ws_aida1145_UPPERCASE1",
        "ws_aida1145_student_01",
        "ws_aida1145_example01;DROP SCHEMA shared_facilities",
        "shared_facilities",
        "ws_aida2156_example01",
    ]
    for schema in unsafe:
        with patch("apex_app.config.st.secrets", {"apex": {"workspace_schema": schema}}):
            assert workspace_schema() == "", schema
            assert workspace_configuration_error(), schema
