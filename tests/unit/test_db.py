from unittest.mock import Mock, patch

import pytest

from apex_app.db import EXPLORER_VIEWS, check_connection_and_workspace, explore_view


def test_explorer_accepts_only_allowlisted_queries() -> None:
    connection = Mock()
    with patch("apex_app.db.apex_connection", return_value=connection):
        explore_view("Facility profiles")
        connection.query.assert_called_once_with(EXPLORER_VIEWS["Facility profiles"], ttl="5m")


def test_explorer_rejects_arbitrary_query_text() -> None:
    with pytest.raises(ValueError, match="not approved"):
        explore_view("SELECT * FROM public.apex_workspace_registry")


def test_workspace_check_uses_parameter_binding_and_fresh_result() -> None:
    connection = Mock()
    schema = "ws_aida1145_example01"
    with patch("apex_app.db.apex_connection", return_value=connection):
        check_connection_and_workspace(schema)
    call = connection.query.call_args
    assert call.kwargs["params"] == {"workspace": schema}
    assert call.kwargs["ttl"] == 0
    assert schema not in call.args[0]
