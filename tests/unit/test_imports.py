import importlib


def test_application_modules_import() -> None:
    for module in (
        "apex_app.catalogue",
        "apex_app.config",
        "apex_app.db",
        "apex_app.lab_page",
        "apex_app.ui",
    ):
        importlib.import_module(module)
