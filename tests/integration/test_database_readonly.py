import os
from urllib.parse import urlsplit

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.exc import DBAPIError


pytestmark = pytest.mark.database


def student_database_url() -> str:
    url = os.getenv("APEX_TEST_DATABASE_URL", "")
    if not url:
        pytest.skip("Set APEX_TEST_DATABASE_URL to a non-admin AIDA 1145 student login.")
    username = urlsplit(url.replace("postgresql+psycopg", "postgresql", 1)).username or ""
    if username in {"apex_admin", "postgres"} or not username.startswith("apex_u_"):
        pytest.fail("APEX_TEST_DATABASE_URL must use an apex_u_ non-admin student login.")
    return url


def test_student_can_read_shared_data_but_cannot_write_shared_schema() -> None:
    engine = create_engine(student_database_url(), pool_pre_ping=True)
    try:
        with engine.connect() as connection:
            identity = connection.execute(
                text("SELECT current_user, current_database()")
            ).one()
            assert identity[0].startswith("apex_u_")
            assert identity[1] == "apex_facilities"
            count = connection.execute(
                text("SELECT count(*) FROM shared_facilities.v_facility_profile")
            ).scalar_one()
            assert count >= 30
            synthetic = connection.execute(
                text("SELECT bool_and(synthetic_record) FROM shared_facilities.clients")
            ).scalar_one()
            assert synthetic is True

        with engine.begin() as connection, pytest.raises(DBAPIError):
            connection.execute(
                text("CREATE TABLE shared_facilities.app_test_must_not_exist (id integer)")
            )
    finally:
        engine.dispose()
