BEGIN;

-- Stable, student-facing query interfaces for the connected Apex domains.
-- These views simplify common joins without embedding course assessment answers.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apex_platform_owner') THEN
        CREATE ROLE apex_platform_owner NOLOGIN;
    END IF;
END
$$;

GRANT USAGE, CREATE ON SCHEMA
    shared_facilities,
    shared_crm,
    shared_readiness,
    shared_operations,
    shared_workforce,
    shared_quality,
    shared_assets,
    shared_supply,
    shared_finance,
    shared_insights,
    shared_spatial,
    shared_research
TO apex_platform_owner;

CREATE VIEW shared_facilities.v_facility_profile (
    facility_id,
    facility_code,
    facility_name,
    facility_type,
    city,
    province_code,
    floor_area_m2,
    opened_year,
    operating_status,
    client_id,
    client_code,
    client_name,
    client_sector,
    client_status,
    space_count,
    service_area_m2,
    highest_service_priority
) WITH (security_invoker = true) AS
SELECT
    f.facility_id,
    f.facility_code,
    f.facility_name,
    f.facility_type,
    f.city,
    f.province_code,
    f.floor_area_m2,
    f.opened_year,
    f.operating_status,
    c.client_id,
    c.client_code,
    c.client_name,
    c.sector AS client_sector,
    c.status AS client_status,
    count(s.space_id)::integer AS space_count,
    COALESCE(sum(s.area_m2), 0::numeric) AS service_area_m2,
    max(s.service_priority) AS highest_service_priority
FROM shared_facilities.facilities AS f
JOIN shared_facilities.clients AS c USING (client_id)
LEFT JOIN shared_facilities.spaces AS s USING (facility_id)
GROUP BY
    f.facility_id,
    c.client_id;

COMMENT ON VIEW shared_facilities.v_facility_profile IS
    'Student-facing facility and client profile with summarized service-space measures.';

CREATE VIEW shared_readiness.v_readiness_status (
    mobilization_id,
    contract_id,
    contract_code,
    facility_id,
    facility_code,
    facility_name,
    planned_start_date,
    go_live_date,
    mobilization_status,
    readiness_score,
    risk_level,
    total_task_count,
    completed_task_count,
    blocked_task_count,
    overdue_open_task_count,
    task_completion_percent
) WITH (security_invoker = true) AS
SELECT
    m.mobilization_id,
    c.contract_id,
    c.contract_code,
    f.facility_id,
    f.facility_code,
    f.facility_name,
    m.planned_start_date,
    m.go_live_date,
    m.status AS mobilization_status,
    m.readiness_score,
    m.risk_level,
    count(t.readiness_task_id)::integer AS total_task_count,
    count(*) FILTER (WHERE t.status = 'complete')::integer AS completed_task_count,
    count(*) FILTER (WHERE t.status = 'blocked')::integer AS blocked_task_count,
    count(*) FILTER (
        WHERE t.status <> 'complete'
          AND t.due_date < date '2026-08-12'
    )::integer AS overdue_open_task_count,
    round(
        100.0 * count(*) FILTER (WHERE t.status = 'complete')
        / NULLIF(count(t.readiness_task_id), 0),
        2
    ) AS task_completion_percent
FROM shared_readiness.mobilizations AS m
JOIN shared_crm.contracts AS c USING (contract_id)
JOIN shared_facilities.facilities AS f USING (facility_id)
LEFT JOIN shared_readiness.readiness_tasks AS t USING (mobilization_id)
GROUP BY
    m.mobilization_id,
    c.contract_id,
    f.facility_id;

COMMENT ON VIEW shared_readiness.v_readiness_status IS
    'Student-facing contract mobilization status with task completion and fixed 2026-08-12 learning-snapshot indicators.';

CREATE VIEW shared_operations.v_service_visit_detail (
    service_visit_id,
    contract_id,
    contract_code,
    facility_id,
    facility_code,
    facility_name,
    client_id,
    client_code,
    service_type_id,
    service_code,
    service_name,
    service_category,
    scheduled_start,
    scheduled_end,
    actual_start,
    actual_end,
    visit_status,
    crew_size,
    planned_minutes,
    actual_minutes,
    start_variance_minutes,
    duration_variance_minutes
) WITH (security_invoker = true) AS
SELECT
    v.service_visit_id,
    c.contract_id,
    c.contract_code,
    f.facility_id,
    f.facility_code,
    f.facility_name,
    cl.client_id,
    cl.client_code,
    st.service_type_id,
    st.service_code,
    st.service_name,
    st.service_category,
    v.scheduled_start,
    v.scheduled_end,
    v.actual_start,
    v.actual_end,
    v.visit_status,
    v.crew_size,
    v.planned_minutes,
    v.actual_minutes,
    CASE
        WHEN v.actual_start IS NULL THEN NULL
        ELSE round((extract(epoch FROM (v.actual_start - v.scheduled_start)) / 60.0)::numeric, 2)
    END AS start_variance_minutes,
    CASE
        WHEN v.actual_minutes IS NULL THEN NULL
        ELSE v.actual_minutes - v.planned_minutes
    END AS duration_variance_minutes
FROM shared_operations.service_visits AS v
JOIN shared_crm.contracts AS c USING (contract_id)
JOIN shared_facilities.facilities AS f ON f.facility_id = v.facility_id
JOIN shared_facilities.clients AS cl ON cl.client_id = f.client_id
JOIN shared_operations.service_types AS st USING (service_type_id);

COMMENT ON VIEW shared_operations.v_service_visit_detail IS
    'Student-facing service visit detail with contract, facility, client, service type, and schedule variance fields.';

CREATE VIEW shared_operations.v_work_order_asset_detail (
    work_order_id,
    facility_id,
    facility_code,
    facility_name,
    asset_id,
    asset_code,
    asset_type_code,
    asset_type_name,
    asset_category,
    asset_condition_score,
    asset_criticality,
    asset_operating_status,
    service_visit_id,
    created_at,
    due_at,
    resolved_at,
    priority,
    work_order_category,
    work_order_status,
    labour_hours,
    resolution_hours,
    due_status
) WITH (security_invoker = true) AS
SELECT
    w.work_order_id,
    f.facility_id,
    f.facility_code,
    f.facility_name,
    a.asset_id,
    a.asset_code,
    at.asset_type_code,
    at.asset_type_name,
    at.category AS asset_category,
    a.condition_score AS asset_condition_score,
    a.criticality AS asset_criticality,
    a.operating_status AS asset_operating_status,
    w.service_visit_id,
    w.created_at,
    w.due_at,
    w.resolved_at,
    w.priority,
    w.category AS work_order_category,
    w.status AS work_order_status,
    w.labour_hours,
    CASE
        WHEN w.resolved_at IS NULL THEN NULL
        ELSE round((extract(epoch FROM (w.resolved_at - w.created_at)) / 3600.0)::numeric, 2)
    END AS resolution_hours,
    CASE
        WHEN w.resolved_at IS NOT NULL AND w.resolved_at <= w.due_at THEN 'resolved_on_time'
        WHEN w.resolved_at IS NOT NULL THEN 'resolved_late'
        WHEN w.due_at < timestamptz '2026-08-12 23:59:59-06' THEN 'overdue_open'
        ELSE 'open_not_due'
    END AS due_status
FROM shared_operations.work_orders AS w
JOIN shared_facilities.facilities AS f USING (facility_id)
LEFT JOIN shared_assets.assets AS a USING (asset_id)
LEFT JOIN shared_assets.asset_types AS at USING (asset_type_id);

COMMENT ON VIEW shared_operations.v_work_order_asset_detail IS
    'Student-facing work order and asset detail with resolution duration and fixed learning-snapshot due status.';

CREATE VIEW shared_quality.v_facility_quality_summary (
    facility_id,
    facility_code,
    facility_name,
    inspection_count,
    passed_inspection_count,
    pass_rate_percent,
    average_inspection_score,
    open_finding_count,
    major_or_critical_finding_count,
    feedback_count,
    average_feedback_rating,
    average_response_days
) WITH (security_invoker = true) AS
WITH inspection_summary AS (
    SELECT
        i.facility_id,
        count(*)::integer AS inspection_count,
        count(*) FILTER (WHERE i.passed)::integer AS passed_inspection_count,
        round(100.0 * count(*) FILTER (WHERE i.passed) / NULLIF(count(*), 0), 2) AS pass_rate_percent,
        round(avg(i.score), 2) AS average_inspection_score
    FROM shared_quality.inspections AS i
    GROUP BY i.facility_id
), finding_summary AS (
    SELECT
        i.facility_id,
        count(*) FILTER (WHERE finding.closed_at IS NULL)::integer AS open_finding_count,
        count(*) FILTER (WHERE finding.severity IN ('major', 'critical'))::integer AS major_or_critical_finding_count
    FROM shared_quality.inspection_findings AS finding
    JOIN shared_quality.inspections AS i USING (inspection_id)
    GROUP BY i.facility_id
), feedback_summary AS (
    SELECT
        feedback.facility_id,
        count(*)::integer AS feedback_count,
        round(avg(feedback.rating), 2) AS average_feedback_rating,
        round(avg(feedback.response_days), 2) AS average_response_days
    FROM shared_quality.service_feedback AS feedback
    GROUP BY feedback.facility_id
)
SELECT
    f.facility_id,
    f.facility_code,
    f.facility_name,
    COALESCE(i.inspection_count, 0) AS inspection_count,
    COALESCE(i.passed_inspection_count, 0) AS passed_inspection_count,
    i.pass_rate_percent,
    i.average_inspection_score,
    COALESCE(fs.open_finding_count, 0) AS open_finding_count,
    COALESCE(fs.major_or_critical_finding_count, 0) AS major_or_critical_finding_count,
    COALESCE(feedback.feedback_count, 0) AS feedback_count,
    feedback.average_feedback_rating,
    feedback.average_response_days
FROM shared_facilities.facilities AS f
LEFT JOIN inspection_summary AS i USING (facility_id)
LEFT JOIN finding_summary AS fs USING (facility_id)
LEFT JOIN feedback_summary AS feedback USING (facility_id);

COMMENT ON VIEW shared_quality.v_facility_quality_summary IS
    'Student-facing facility-level quality, findings, and service-feedback summary without join fan-out.';

CREATE VIEW shared_finance.v_facility_financial_summary (
    facility_id,
    facility_code,
    facility_name,
    contract_count,
    active_contract_count,
    contracted_monthly_value,
    invoice_count,
    invoiced_subtotal,
    paid_subtotal,
    overdue_subtotal,
    cost_entry_count,
    recorded_operating_cost,
    labour_cost,
    material_cost
) WITH (security_invoker = true) AS
WITH contract_summary AS (
    SELECT
        c.facility_id,
        count(*)::integer AS contract_count,
        count(*) FILTER (WHERE c.status = 'active')::integer AS active_contract_count,
        sum(c.monthly_value) AS contracted_monthly_value
    FROM shared_crm.contracts AS c
    GROUP BY c.facility_id
), invoice_summary AS (
    SELECT
        c.facility_id,
        count(i.invoice_id)::integer AS invoice_count,
        sum(i.subtotal) AS invoiced_subtotal,
        sum(i.subtotal) FILTER (WHERE i.invoice_status = 'paid') AS paid_subtotal,
        sum(i.subtotal) FILTER (WHERE i.invoice_status = 'overdue') AS overdue_subtotal
    FROM shared_crm.contracts AS c
    JOIN shared_finance.invoices AS i USING (contract_id)
    GROUP BY c.facility_id
), cost_summary AS (
    SELECT
        ce.facility_id,
        count(*)::integer AS cost_entry_count,
        sum(ce.amount) AS recorded_operating_cost,
        sum(ce.amount) FILTER (WHERE ce.cost_category = 'labour') AS labour_cost,
        sum(ce.amount) FILTER (WHERE ce.cost_category = 'materials') AS material_cost
    FROM shared_finance.cost_entries AS ce
    GROUP BY ce.facility_id
)
SELECT
    f.facility_id,
    f.facility_code,
    f.facility_name,
    COALESCE(c.contract_count, 0) AS contract_count,
    COALESCE(c.active_contract_count, 0) AS active_contract_count,
    COALESCE(c.contracted_monthly_value, 0::numeric) AS contracted_monthly_value,
    COALESCE(i.invoice_count, 0) AS invoice_count,
    COALESCE(i.invoiced_subtotal, 0::numeric) AS invoiced_subtotal,
    COALESCE(i.paid_subtotal, 0::numeric) AS paid_subtotal,
    COALESCE(i.overdue_subtotal, 0::numeric) AS overdue_subtotal,
    COALESCE(cost.cost_entry_count, 0) AS cost_entry_count,
    COALESCE(cost.recorded_operating_cost, 0::numeric) AS recorded_operating_cost,
    COALESCE(cost.labour_cost, 0::numeric) AS labour_cost,
    COALESCE(cost.material_cost, 0::numeric) AS material_cost
FROM shared_facilities.facilities AS f
LEFT JOIN contract_summary AS c USING (facility_id)
LEFT JOIN invoice_summary AS i USING (facility_id)
LEFT JOIN cost_summary AS cost USING (facility_id);

COMMENT ON VIEW shared_finance.v_facility_financial_summary IS
    'Student-facing facility finance summary that keeps contract, invoice, and cost aggregations independent.';

CREATE VIEW shared_supply.v_inventory_movement_detail (
    inventory_transaction_id,
    transaction_date,
    transaction_type,
    quantity,
    quantity_direction,
    reference_code,
    facility_id,
    facility_code,
    facility_name,
    product_id,
    product_code,
    product_name,
    product_category,
    unit_of_measure,
    unit_cost,
    estimated_transaction_value,
    reorder_level,
    vendor_id,
    vendor_code,
    vendor_name,
    vendor_category,
    lead_time_days
) WITH (security_invoker = true) AS
SELECT
    tx.inventory_transaction_id,
    tx.transaction_date,
    tx.transaction_type,
    tx.quantity,
    CASE WHEN tx.quantity > 0 THEN 'inbound' ELSE 'outbound' END AS quantity_direction,
    tx.reference_code,
    f.facility_id,
    f.facility_code,
    f.facility_name,
    p.product_id,
    p.product_code,
    p.product_name,
    p.product_category,
    p.unit_of_measure,
    p.unit_cost,
    round(abs(tx.quantity) * p.unit_cost, 2) AS estimated_transaction_value,
    p.reorder_level,
    v.vendor_id,
    v.vendor_code,
    v.vendor_name,
    v.vendor_category,
    v.lead_time_days
FROM shared_supply.inventory_transactions AS tx
JOIN shared_facilities.facilities AS f USING (facility_id)
JOIN shared_supply.products AS p USING (product_id)
JOIN shared_supply.vendors AS v USING (vendor_id);

COMMENT ON VIEW shared_supply.v_inventory_movement_detail IS
    'Student-facing inventory movement detail with facility, product, vendor, direction, and estimated value.';

CREATE VIEW shared_insights.v_client_performance_summary (
    client_id,
    client_code,
    client_name,
    client_sector,
    client_status,
    relationship_start,
    segment_name,
    annual_value_band,
    service_complexity,
    retention_risk,
    facility_count,
    active_facility_count,
    metric_month_count,
    total_completed_visits,
    total_missed_visits,
    average_quality_score,
    total_labour_hours,
    total_operating_cost,
    average_client_rating
) WITH (security_invoker = true) AS
WITH facility_summary AS (
    SELECT
        f.client_id,
        count(*)::integer AS facility_count,
        count(*) FILTER (WHERE f.operating_status = 'active')::integer AS active_facility_count
    FROM shared_facilities.facilities AS f
    GROUP BY f.client_id
), metric_summary AS (
    SELECT
        f.client_id,
        count(*)::integer AS metric_month_count,
        sum(m.completed_visits)::bigint AS total_completed_visits,
        sum(m.missed_visits)::bigint AS total_missed_visits,
        round(avg(m.quality_score), 2) AS average_quality_score,
        sum(m.labour_hours) AS total_labour_hours,
        sum(m.operating_cost) AS total_operating_cost,
        round(avg(m.client_rating), 2) AS average_client_rating
    FROM shared_insights.monthly_operational_metrics AS m
    JOIN shared_facilities.facilities AS f USING (facility_id)
    GROUP BY f.client_id
)
SELECT
    c.client_id,
    c.client_code,
    c.client_name,
    c.sector AS client_sector,
    c.status AS client_status,
    c.relationship_start,
    segment.segment_name,
    segment.annual_value_band,
    segment.service_complexity,
    segment.retention_risk,
    COALESCE(f.facility_count, 0) AS facility_count,
    COALESCE(f.active_facility_count, 0) AS active_facility_count,
    COALESCE(m.metric_month_count, 0) AS metric_month_count,
    COALESCE(m.total_completed_visits, 0) AS total_completed_visits,
    COALESCE(m.total_missed_visits, 0) AS total_missed_visits,
    m.average_quality_score,
    COALESCE(m.total_labour_hours, 0::numeric) AS total_labour_hours,
    COALESCE(m.total_operating_cost, 0::numeric) AS total_operating_cost,
    m.average_client_rating
FROM shared_facilities.clients AS c
LEFT JOIN shared_insights.customer_segments AS segment USING (client_id)
LEFT JOIN facility_summary AS f USING (client_id)
LEFT JOIN metric_summary AS m USING (client_id);

COMMENT ON VIEW shared_insights.v_client_performance_summary IS
    'Student-facing client and segment profile with facility and monthly operational performance summaries.';

CREATE VIEW shared_spatial.v_service_route_summary (
    service_visit_id,
    facility_id,
    facility_code,
    facility_name,
    territory_id,
    territory_code,
    territory_name,
    service_region,
    first_event_time,
    last_event_time,
    route_event_count,
    recorded_route_minutes,
    start_longitude,
    start_latitude,
    end_longitude,
    end_latitude,
    route_path,
    route_length_metres
) WITH (security_invoker = true) AS
SELECT
    r.service_visit_id,
    f.facility_id,
    f.facility_code,
    f.facility_name,
    t.territory_id,
    t.territory_code,
    t.territory_name,
    t.service_region,
    min(r.event_time) AS first_event_time,
    max(r.event_time) AS last_event_time,
    count(*)::integer AS route_event_count,
    round((extract(epoch FROM (max(r.event_time) - min(r.event_time))) / 60.0)::numeric, 2) AS recorded_route_minutes,
    ST_X((array_agg(r.location ORDER BY r.event_time, r.route_event_id))[1]) AS start_longitude,
    ST_Y((array_agg(r.location ORDER BY r.event_time, r.route_event_id))[1]) AS start_latitude,
    ST_X((array_agg(r.location ORDER BY r.event_time DESC, r.route_event_id DESC))[1]) AS end_longitude,
    ST_Y((array_agg(r.location ORDER BY r.event_time DESC, r.route_event_id DESC))[1]) AS end_latitude,
    ST_MakeLine(r.location ORDER BY r.event_time, r.route_event_id) AS route_path,
    round(ST_Length(ST_MakeLine(r.location ORDER BY r.event_time, r.route_event_id)::geography)::numeric, 2) AS route_length_metres
FROM shared_spatial.route_events AS r
JOIN shared_facilities.facilities AS f USING (facility_id)
JOIN shared_spatial.service_territories AS t USING (territory_id)
GROUP BY
    r.service_visit_id,
    f.facility_id,
    t.territory_id;

COMMENT ON VIEW shared_spatial.v_service_route_summary IS
    'Student-facing per-visit PostGIS route summary with ordered path, endpoints, duration, and geodesic length.';

CREATE VIEW shared_research.v_lab_data_package_catalog (
    data_package_id,
    package_code,
    package_title,
    course_code,
    lab_number,
    package_version,
    release_status,
    learning_purpose,
    released_at,
    dataset_count,
    dataset_codes,
    dataset_titles,
    source_types,
    licence_names,
    contains_personal_information,
    package_quality_notes
) WITH (security_invoker = true) AS
SELECT
    p.data_package_id,
    p.package_code,
    p.package_title,
    p.course_code,
    p.lab_number,
    p.package_version,
    p.release_status,
    p.learning_purpose,
    p.released_at,
    count(d.dataset_id)::integer AS dataset_count,
    array_agg(d.dataset_code ORDER BY link.position) FILTER (WHERE d.dataset_id IS NOT NULL) AS dataset_codes,
    array_agg(d.dataset_title ORDER BY link.position) FILTER (WHERE d.dataset_id IS NOT NULL) AS dataset_titles,
    array_agg(DISTINCT d.source_type) FILTER (WHERE d.dataset_id IS NOT NULL) AS source_types,
    array_agg(DISTINCT d.licence_name) FILTER (WHERE d.dataset_id IS NOT NULL) AS licence_names,
    COALESCE(bool_or(d.contains_personal_information), false) AS contains_personal_information,
    string_agg(DISTINCT d.quality_notes, ' | ') FILTER (WHERE d.dataset_id IS NOT NULL) AS package_quality_notes
FROM shared_research.data_packages AS p
LEFT JOIN LATERAL unnest(p.dataset_ids) WITH ORDINALITY AS link(dataset_id, position) ON true
LEFT JOIN shared_research.dataset_catalog AS d ON d.dataset_id = link.dataset_id
GROUP BY p.data_package_id;

COMMENT ON VIEW shared_research.v_lab_data_package_catalog IS
    'Student-facing lab package catalogue with ordered dataset identifiers and summarized provenance metadata.';

ALTER VIEW shared_facilities.v_facility_profile OWNER TO apex_platform_owner;
ALTER VIEW shared_readiness.v_readiness_status OWNER TO apex_platform_owner;
ALTER VIEW shared_operations.v_service_visit_detail OWNER TO apex_platform_owner;
ALTER VIEW shared_operations.v_work_order_asset_detail OWNER TO apex_platform_owner;
ALTER VIEW shared_quality.v_facility_quality_summary OWNER TO apex_platform_owner;
ALTER VIEW shared_finance.v_facility_financial_summary OWNER TO apex_platform_owner;
ALTER VIEW shared_supply.v_inventory_movement_detail OWNER TO apex_platform_owner;
ALTER VIEW shared_insights.v_client_performance_summary OWNER TO apex_platform_owner;
ALTER VIEW shared_spatial.v_service_route_summary OWNER TO apex_platform_owner;
ALTER VIEW shared_research.v_lab_data_package_catalog OWNER TO apex_platform_owner;

REVOKE ALL ON TABLE
    shared_facilities.v_facility_profile,
    shared_readiness.v_readiness_status,
    shared_operations.v_service_visit_detail,
    shared_operations.v_work_order_asset_detail,
    shared_quality.v_facility_quality_summary,
    shared_finance.v_facility_financial_summary,
    shared_supply.v_inventory_movement_detail,
    shared_insights.v_client_performance_summary,
    shared_spatial.v_service_route_summary,
    shared_research.v_lab_data_package_catalog
FROM PUBLIC;

GRANT SELECT ON TABLE
    shared_facilities.v_facility_profile,
    shared_readiness.v_readiness_status,
    shared_operations.v_service_visit_detail,
    shared_operations.v_work_order_asset_detail,
    shared_quality.v_facility_quality_summary,
    shared_finance.v_facility_financial_summary,
    shared_supply.v_inventory_movement_detail,
    shared_insights.v_client_performance_summary,
    shared_spatial.v_service_route_summary,
    shared_research.v_lab_data_package_catalog
TO apex_shared_reader;

COMMIT;
