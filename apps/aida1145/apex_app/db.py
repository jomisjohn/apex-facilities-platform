import streamlit as st

from apex_app.config import READ_TTL


EXPLORER_VIEWS = {
    "Facility profiles": "SELECT * FROM shared_facilities.v_facility_profile ORDER BY facility_id LIMIT 250",
    "Readiness status": "SELECT * FROM shared_readiness.v_readiness_status ORDER BY mobilization_id LIMIT 250",
    "Service visits": "SELECT * FROM shared_operations.v_service_visit_detail ORDER BY scheduled_start DESC LIMIT 250",
    "Work orders and assets": "SELECT * FROM shared_operations.v_work_order_asset_detail ORDER BY created_at DESC LIMIT 250",
    "Facility quality": "SELECT * FROM shared_quality.v_facility_quality_summary ORDER BY facility_id LIMIT 250",
    "Facility finance": "SELECT * FROM shared_finance.v_facility_financial_summary ORDER BY facility_id LIMIT 250",
    "Inventory movements": "SELECT * FROM shared_supply.v_inventory_movement_detail ORDER BY transaction_date DESC LIMIT 250",
    "Client performance": "SELECT * FROM shared_insights.v_client_performance_summary ORDER BY client_id LIMIT 250",
    "Service routes": "SELECT * FROM shared_spatial.v_service_route_summary ORDER BY service_visit_id DESC LIMIT 250",
}


def apex_connection():
    """Return the single supported SQLAlchemy-backed Apex connection."""
    return st.connection("apex", type="sql")


def check_connection_and_workspace(schema: str):
    """Return current identity and fresh workspace privileges."""
    return apex_connection().query(
        """
        SELECT
            current_database() AS database_name,
            current_user AS database_user,
            %(workspace)s AS workspace_schema,
            has_schema_privilege(current_user, %(workspace)s, 'USAGE') AS can_use_workspace,
            has_schema_privilege(current_user, %(workspace)s, 'CREATE') AS can_create_in_workspace,
            has_schema_privilege(current_user, 'shared_facilities', 'USAGE') AS can_use_shared_data
        """,
        params={"workspace": schema},
        ttl=0,
        show_spinner="Checking your database access...",
    )


def explore_view(label: str):
    """Query one hard-coded, approved shared view."""
    if label not in EXPLORER_VIEWS:
        raise ValueError("That data view is not approved for the explorer.")
    return apex_connection().query(EXPLORER_VIEWS[label], ttl=READ_TTL)


def load_lab_catalogue():
    """Load current AIDA 1145 package metadata with bounded caching."""
    return apex_connection().query(
        """
        SELECT lab_number, package_code, package_title, package_version,
               release_status, learning_purpose, dataset_count, dataset_codes,
               source_types, licence_names, contains_personal_information
        FROM shared_research.v_lab_data_package_catalog
        WHERE course_code = 'AIDA 1145'
        ORDER BY lab_number
        """,
        ttl=READ_TTL,
        show_spinner="Loading the lab catalogue...",
    )
