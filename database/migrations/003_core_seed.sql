BEGIN;

-- All records in this migration are deterministic and fictional. They are
-- designed for repeatable labs, demonstrations, automated checks, and recovery
-- tests. No person, organization, address, or production system is represented.

-- Identity sequences are not transactional in PostgreSQL. Reset them only when
-- the shared data layer is empty so a corrected migration remains repeatable
-- after a rolled-back development run without deleting any existing records.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM shared_facilities.clients)
       OR EXISTS (SELECT 1 FROM shared_workforce.employees)
       OR EXISTS (SELECT 1 FROM shared_assets.asset_types)
       OR EXISTS (SELECT 1 FROM shared_operations.service_types)
       OR EXISTS (SELECT 1 FROM shared_supply.vendors)
       OR EXISTS (SELECT 1 FROM shared_spatial.service_territories)
       OR EXISTS (SELECT 1 FROM shared_research.dataset_catalog) THEN
        RAISE EXCEPTION 'Core seed migration requires empty shared tables.';
    END IF;
END
$$;

ALTER TABLE shared_facilities.clients ALTER COLUMN client_id RESTART WITH 1;
ALTER TABLE shared_facilities.facilities ALTER COLUMN facility_id RESTART WITH 1;
ALTER TABLE shared_facilities.spaces ALTER COLUMN space_id RESTART WITH 1;
ALTER TABLE shared_crm.opportunities ALTER COLUMN opportunity_id RESTART WITH 1;
ALTER TABLE shared_crm.contracts ALTER COLUMN contract_id RESTART WITH 1;
ALTER TABLE shared_readiness.mobilizations ALTER COLUMN mobilization_id RESTART WITH 1;
ALTER TABLE shared_readiness.readiness_tasks ALTER COLUMN readiness_task_id RESTART WITH 1;
ALTER TABLE shared_workforce.employees ALTER COLUMN employee_id RESTART WITH 1;
ALTER TABLE shared_assets.asset_types ALTER COLUMN asset_type_id RESTART WITH 1;
ALTER TABLE shared_assets.assets ALTER COLUMN asset_id RESTART WITH 1;
ALTER TABLE shared_assets.maintenance_plans ALTER COLUMN maintenance_plan_id RESTART WITH 1;
ALTER TABLE shared_assets.maintenance_events ALTER COLUMN maintenance_event_id RESTART WITH 1;
ALTER TABLE shared_assets.sensor_readings ALTER COLUMN sensor_reading_id RESTART WITH 1;
ALTER TABLE shared_operations.service_types ALTER COLUMN service_type_id RESTART WITH 1;
ALTER TABLE shared_operations.service_visits ALTER COLUMN service_visit_id RESTART WITH 1;
ALTER TABLE shared_operations.work_orders ALTER COLUMN work_order_id RESTART WITH 1;
ALTER TABLE shared_workforce.shifts ALTER COLUMN shift_id RESTART WITH 1;
ALTER TABLE shared_quality.inspections ALTER COLUMN inspection_id RESTART WITH 1;
ALTER TABLE shared_quality.inspection_findings ALTER COLUMN finding_id RESTART WITH 1;
ALTER TABLE shared_quality.service_feedback ALTER COLUMN feedback_id RESTART WITH 1;
ALTER TABLE shared_supply.vendors ALTER COLUMN vendor_id RESTART WITH 1;
ALTER TABLE shared_supply.products ALTER COLUMN product_id RESTART WITH 1;
ALTER TABLE shared_supply.inventory_transactions ALTER COLUMN inventory_transaction_id RESTART WITH 1;
ALTER TABLE shared_finance.estimates ALTER COLUMN estimate_id RESTART WITH 1;
ALTER TABLE shared_finance.invoices ALTER COLUMN invoice_id RESTART WITH 1;
ALTER TABLE shared_finance.cost_entries ALTER COLUMN cost_entry_id RESTART WITH 1;
ALTER TABLE shared_spatial.service_territories ALTER COLUMN territory_id RESTART WITH 1;
ALTER TABLE shared_spatial.route_events ALTER COLUMN route_event_id RESTART WITH 1;
ALTER TABLE shared_research.dataset_catalog ALTER COLUMN dataset_id RESTART WITH 1;
ALTER TABLE shared_research.data_packages ALTER COLUMN data_package_id RESTART WITH 1;
ALTER TABLE shared_research.external_observations ALTER COLUMN observation_id RESTART WITH 1;

INSERT INTO shared_facilities.clients (
    client_code, client_name, sector, relationship_start, status, synthetic_record
)
SELECT
    format('APX-CL-%s', to_char(n, 'FM00')),
    format('Apex Client %s', to_char(n, 'FM00')),
    (ARRAY['education', 'healthcare', 'office', 'retail', 'industrial', 'public'])[((n - 1) % 6) + 1],
    date '2021-01-01' + (n * 67),
    CASE WHEN n = 12 THEN 'prospect' ELSE 'active' END,
    true
FROM generate_series(1, 12) AS series(n);

INSERT INTO shared_facilities.facilities (
    client_id, facility_code, facility_name, facility_type, city, province_code,
    floor_area_m2, opened_year, operating_status, synthetic_record
)
SELECT
    ((n - 1) / 3) + 1,
    format('APX-FAC-%s', to_char(n, 'FM000')),
    format('Apex Facility %s', to_char(n, 'FM000')),
    (ARRAY['learning_centre', 'care_centre', 'office_campus', 'retail_complex', 'industrial_site', 'civic_facility'])[((n - 1) % 6) + 1],
    format('Apex City %s', to_char(((n - 1) % 9) + 1, 'FM00')),
    'AB',
    (2800 + n * 415 + (n % 4) * 275)::numeric(12,2),
    1978 + ((n * 7) % 46),
    CASE WHEN n BETWEEN 31 AND 33 THEN 'mobilizing'
         WHEN n >= 34 THEN 'inactive'
         ELSE 'active' END,
    true
FROM generate_series(1, 36) AS series(n);

INSERT INTO shared_facilities.spaces (
    facility_id, space_code, space_type, floor_level, area_m2, service_priority
)
SELECT
    f.facility_id,
    format('SPACE-%s', to_char(s.n, 'FM00')),
    (ARRAY['entry', 'office', 'washroom', 'meeting_room', 'service_area', 'common_area'])[s.n],
    CASE WHEN s.n = 1 THEN 0 ELSE ((s.n - 2) % 3) + 1 END,
    (120 + f.facility_id * 9 + s.n * 38)::numeric(10,2),
    ((f.facility_id + s.n) % 5) + 1
FROM shared_facilities.facilities AS f
CROSS JOIN generate_series(1, 6) AS s(n);

INSERT INTO shared_crm.opportunities (
    client_id, opened_date, stage, source_channel, estimated_annual_value,
    win_probability, expected_close_date, synthetic_record
)
SELECT
    f.client_id,
    date '2024-01-08' + (f.facility_id * 9),
    CASE
        WHEN f.facility_id <= 33 THEN 'won'
        WHEN f.facility_id = 34 THEN 'proposal'
        WHEN f.facility_id = 35 THEN 'negotiation'
        ELSE 'discovery'
    END,
    (ARRAY['referral', 'facility_assessment', 'industry_event', 'digital_inquiry'])[((f.facility_id - 1) % 4) + 1],
    (125000 + f.facility_id * 11250)::numeric(14,2),
    CASE
        WHEN f.facility_id <= 33 THEN 0.9500
        WHEN f.facility_id = 34 THEN 0.4500
        WHEN f.facility_id = 35 THEN 0.7000
        ELSE 0.2500
    END,
    date '2024-03-01' + (f.facility_id * 9),
    true
FROM shared_facilities.facilities AS f;

INSERT INTO shared_crm.contracts (
    client_id, facility_id, contract_code, start_date, end_date, monthly_value,
    service_level, status, synthetic_record
)
SELECT
    f.client_id,
    f.facility_id,
    format('APX-CON-%s', to_char(f.facility_id, 'FM000')),
    date '2024-07-01' + (f.facility_id * 3),
    date '2027-06-30' + (f.facility_id * 3),
    (14500 + f.facility_id * 525 + (f.facility_id % 4) * 900)::numeric(14,2),
    (ARRAY['standard', 'enhanced', 'critical'])[((f.facility_id - 1) % 3) + 1],
    CASE WHEN f.facility_id > 30 THEN 'mobilizing' ELSE 'active' END,
    true
FROM shared_facilities.facilities AS f
WHERE f.facility_id <= 33;

INSERT INTO shared_readiness.mobilizations (
    contract_id, planned_start_date, go_live_date, status, readiness_score, risk_level
)
SELECT
    c.contract_id,
    c.start_date - 45,
    CASE WHEN c.status = 'active' THEN c.start_date ELSE NULL END,
    CASE WHEN c.status = 'active' THEN 'complete' ELSE 'in_progress' END,
    CASE WHEN c.status = 'active' THEN (88 + (c.contract_id % 12))::numeric(5,2)
         ELSE (58 + c.contract_id % 18)::numeric(5,2) END,
    CASE
        WHEN c.status <> 'active' THEN 'high'
        WHEN c.contract_id % 5 = 0 THEN 'medium'
        ELSE 'low'
    END
FROM shared_crm.contracts AS c;

INSERT INTO shared_readiness.readiness_tasks (
    mobilization_id, task_type, owner_role, due_date, completed_date, status
)
SELECT
    m.mobilization_id,
    (ARRAY[
        'site_assessment', 'staffing_plan', 'supply_setup', 'asset_register',
        'safety_review', 'service_schedule', 'quality_baseline', 'client_handoff'
    ])[t.n],
    (ARRAY[
        'operations_lead', 'workforce_coordinator', 'supply_coordinator', 'asset_coordinator',
        'safety_lead', 'scheduler', 'quality_lead', 'client_success_lead'
    ])[t.n],
    m.planned_start_date + (t.n * 5),
    CASE WHEN m.status = 'complete' OR t.n <= 4 THEN m.planned_start_date + (t.n * 5) - (t.n % 3) ELSE NULL END,
    CASE WHEN m.status = 'complete' OR t.n <= 4 THEN 'complete'
         WHEN t.n = 5 THEN 'in_progress'
         WHEN t.n = 6 AND m.risk_level = 'high' THEN 'blocked'
         ELSE 'not_started' END
FROM shared_readiness.mobilizations AS m
CROSS JOIN generate_series(1, 8) AS t(n);

INSERT INTO shared_workforce.employees (
    employee_code, display_name, role_name, hire_date, employment_status,
    hourly_cost, synthetic_record
)
SELECT
    format('APX-TM-%s', to_char(n, 'FM000')),
    format('Apex Team Member %s', to_char(n, 'FM000')),
    (ARRAY['service_technician', 'team_lead', 'maintenance_technician', 'quality_inspector', 'scheduler'])[((n - 1) % 5) + 1],
    date '2019-01-01' + (n * 23),
    CASE WHEN n % 29 = 0 THEN 'leave' ELSE 'active' END,
    (22.50 + (n % 12) * 1.35)::numeric(8,2),
    true
FROM generate_series(1, 90) AS series(n);

INSERT INTO shared_workforce.employee_skills (
    employee_id, skill_code, proficiency_level, certified_until
)
SELECT
    e.employee_id,
    skill.skill_code,
    ((e.employee_id + skill.skill_number) % 5) + 1,
    CASE WHEN skill.skill_code IN ('equipment_safety', 'quality_audit', 'worksite_safety')
         THEN date '2026-12-31' + ((e.employee_id % 3) * 365)
         ELSE NULL END
FROM shared_workforce.employees AS e
CROSS JOIN LATERAL (
    SELECT skill_number, skill_code
    FROM (VALUES
        (1, 'routine_service'),
        (2, 'equipment_safety'),
        (3, 'asset_inspection'),
        (4, 'quality_audit'),
        (5, 'worksite_safety')
    ) AS skills(skill_number, skill_code)
    WHERE skill_number IN (((e.employee_id - 1) % 5) + 1, (e.employee_id % 5) + 1, ((e.employee_id + 1) % 5) + 1)
) AS skill;

INSERT INTO shared_assets.asset_types (
    asset_type_code, asset_type_name, category, expected_life_years, criticality_default
)
VALUES
    ('AIR-HANDLER', 'Air Handler', 'building_system', 20, 5),
    ('BOILER', 'Boiler', 'building_system', 25, 5),
    ('PUMP', 'Circulation Pump', 'building_system', 15, 4),
    ('ELEVATOR', 'Service Elevator', 'vertical_transport', 25, 5),
    ('FLOOR-UNIT', 'Floor Service Unit', 'service_equipment', 8, 3),
    ('EXTRACTOR', 'Surface Extractor', 'service_equipment', 7, 3),
    ('DISPENSER', 'Supply Dispenser', 'service_equipment', 6, 2),
    ('LIGHTING', 'Lighting Control', 'electrical', 12, 3),
    ('WATER-SENSOR', 'Water Condition Sensor', 'sensor', 5, 4),
    ('AIR-SENSOR', 'Air Quality Sensor', 'sensor', 5, 4);

INSERT INTO shared_assets.assets (
    facility_id, asset_type_id, asset_code, installed_date, condition_score,
    criticality, operating_status, synthetic_record
)
SELECT
    f.facility_id,
    t.asset_type_id,
    format('APX-AST-%s-%s', to_char(f.facility_id, 'FM000'), to_char(t.asset_type_id, 'FM00')),
    date '2017-01-01' + ((f.facility_id * 31 + t.asset_type_id * 47) % 2500),
    (2.40 + ((f.facility_id * 3 + t.asset_type_id * 7) % 25) / 10.0)::numeric(4,2),
    LEAST(5, GREATEST(1, t.criticality_default + CASE WHEN f.facility_id % 7 = 0 THEN 1 ELSE 0 END)),
    CASE
        WHEN (f.facility_id + t.asset_type_id) % 37 = 0 THEN 'offline'
        WHEN (f.facility_id + t.asset_type_id) % 11 = 0 THEN 'degraded'
        ELSE 'active'
    END,
    true
FROM shared_facilities.facilities AS f
CROSS JOIN shared_assets.asset_types AS t;

INSERT INTO shared_assets.maintenance_plans (
    asset_id, task_name, frequency_days, estimated_minutes,
    last_completed_date, next_due_date
)
SELECT
    a.asset_id,
    CASE WHEN a.asset_type_id <= 4 THEN 'Inspect and service building asset'
         WHEN a.asset_type_id <= 8 THEN 'Inspect and service operational equipment'
         ELSE 'Calibrate and verify sensor' END,
    (ARRAY[30, 45, 60, 90, 120, 180])[((a.asset_id - 1) % 6) + 1],
    30 + (a.asset_id % 8) * 15,
    date '2026-01-01' + (a.asset_id % 150),
    date '2026-01-01' + (a.asset_id % 150) + (ARRAY[30, 45, 60, 90, 120, 180])[((a.asset_id - 1) % 6) + 1]
FROM shared_assets.assets AS a;

INSERT INTO shared_assets.maintenance_events (
    asset_id, event_date, event_type, downtime_minutes, labour_hours,
    material_cost, outcome
)
SELECT
    a.asset_id,
    date '2025-02-01' + (e.n * 105) + (a.asset_id % 23),
    CASE
        WHEN (a.asset_id + e.n) % 19 = 0 THEN 'failure'
        WHEN (a.asset_id + e.n) % 7 = 0 THEN 'corrective'
        WHEN e.n % 3 = 0 THEN 'inspection'
        ELSE 'preventive'
    END,
    CASE WHEN (a.asset_id + e.n) % 19 = 0 THEN 180 + (a.asset_id % 8) * 30
         WHEN (a.asset_id + e.n) % 7 = 0 THEN 45 + (a.asset_id % 6) * 15
         ELSE 0 END,
    (0.75 + ((a.asset_id + e.n) % 9) * 0.50)::numeric(8,2),
    CASE WHEN (a.asset_id + e.n) % 19 = 0 THEN (180 + (a.asset_id % 11) * 42)::numeric(12,2)
         ELSE (12 + (a.asset_id % 9) * 8)::numeric(12,2) END,
    CASE WHEN (a.asset_id + e.n) % 19 = 0 THEN 'Asset restored after failure response'
         WHEN (a.asset_id + e.n) % 7 = 0 THEN 'Corrective work completed'
         ELSE 'Planned work completed' END
FROM shared_assets.assets AS a
CROSS JOIN generate_series(0, 3) AS e(n);

INSERT INTO shared_assets.sensor_readings (
    asset_id, observed_at, metric_name, metric_value, metric_unit, quality_flag
)
SELECT
    a.asset_id,
    timestamptz '2026-06-01 00:00:00-06' + (r.n * interval '8 hours') + ((a.asset_id % 12) * interval '2 minutes'),
    CASE WHEN a.asset_type_id IN (9, 10) THEN 'condition_index' ELSE 'operating_load' END,
    CASE WHEN a.asset_type_id IN (9, 10)
         THEN (55 + ((a.asset_id * 7 + r.n * 3) % 400) / 10.0)::numeric(14,4)
         ELSE (35 + ((a.asset_id * 5 + r.n * 2) % 600) / 10.0)::numeric(14,4) END,
    CASE WHEN a.asset_type_id IN (9, 10) THEN 'index' ELSE 'percent' END,
    CASE WHEN (a.asset_id + r.n) % 41 = 0 THEN 'suspect'
         WHEN (a.asset_id + r.n) % 17 = 0 THEN 'estimated'
         ELSE 'valid' END
FROM shared_assets.assets AS a
CROSS JOIN generate_series(0, 47) AS r(n);

INSERT INTO shared_operations.service_types (
    service_code, service_name, service_category, standard_minutes, standard_unit_cost
)
VALUES
    ('ROUTINE', 'Routine Facility Service', 'scheduled_service', 120, 185.00),
    ('DEEP', 'Detailed Facility Service', 'scheduled_service', 240, 420.00),
    ('READINESS', 'Space Readiness Service', 'readiness', 180, 315.00),
    ('RESTOCK', 'Supply Restocking', 'supply', 60, 95.00),
    ('QUALITY', 'Quality Recovery Service', 'quality', 90, 165.00),
    ('ASSET-PM', 'Asset Preventive Maintenance', 'maintenance', 150, 285.00),
    ('RESPONSE', 'Service Request Response', 'responsive_service', 75, 145.00),
    ('SEASONAL', 'Seasonal Facility Preparation', 'seasonal', 300, 540.00);

INSERT INTO shared_operations.service_visits (
    contract_id, facility_id, service_type_id, scheduled_start, scheduled_end,
    actual_start, actual_end, visit_status, crew_size, planned_minutes, actual_minutes
)
SELECT
    c.contract_id,
    c.facility_id,
    ((v.n - 1) % 8) + 1,
    timestamptz '2025-01-06 07:00:00-07' + ((v.n - 1) * interval '8 days') + ((c.facility_id % 6) * interval '45 minutes'),
    timestamptz '2025-01-06 07:00:00-07' + ((v.n - 1) * interval '8 days') + ((c.facility_id % 6) * interval '45 minutes')
        + ((ARRAY[120,240,180,60,90,150,75,300])[((v.n - 1) % 8) + 1] * interval '1 minute'),
    CASE WHEN (c.facility_id + v.n) % 29 <> 0
         THEN timestamptz '2025-01-06 07:00:00-07' + ((v.n - 1) * interval '8 days') + ((c.facility_id % 6) * interval '45 minutes')
              + (((c.facility_id + v.n) % 13) - 5) * interval '1 minute' END,
    CASE WHEN (c.facility_id + v.n) % 29 <> 0
         THEN timestamptz '2025-01-06 07:00:00-07' + ((v.n - 1) * interval '8 days') + ((c.facility_id % 6) * interval '45 minutes')
              + (((c.facility_id + v.n) % 13) - 5) * interval '1 minute'
              + ((ARRAY[120,240,180,60,90,150,75,300])[((v.n - 1) % 8) + 1] + ((c.facility_id + v.n) % 31) - 12) * interval '1 minute' END,
    CASE WHEN (c.facility_id + v.n) % 29 = 0 THEN 'missed' ELSE 'complete' END,
    2 + ((c.facility_id + v.n) % 4),
    (ARRAY[120,240,180,60,90,150,75,300])[((v.n - 1) % 8) + 1],
    CASE WHEN (c.facility_id + v.n) % 29 <> 0
         THEN GREATEST(30, (ARRAY[120,240,180,60,90,150,75,300])[((v.n - 1) % 8) + 1] + ((c.facility_id + v.n) % 31) - 12) END
FROM shared_crm.contracts AS c
CROSS JOIN generate_series(1, 72) AS v(n);

INSERT INTO shared_operations.work_orders (
    facility_id, asset_id, service_visit_id, created_at, due_at, resolved_at,
    priority, category, status, labour_hours
)
SELECT
    f.facility_id,
    ((f.facility_id - 1) * 10) + ((w.n - 1) % 10) + 1,
    CASE WHEN f.facility_id <= 33
         THEN ((f.facility_id - 1) * 72) + ((w.n * 3 - 1) % 72) + 1
         ELSE NULL END,
    timestamptz '2025-03-01 09:00:00-07' + (w.n * interval '24 days') + (f.facility_id * interval '2 hours'),
    timestamptz '2025-03-01 09:00:00-07' + (w.n * interval '24 days') + (f.facility_id * interval '2 hours')
        + (CASE WHEN w.n % 10 = 0 THEN interval '8 hours' ELSE interval '3 days' END),
    CASE WHEN w.n <= 18
         THEN timestamptz '2025-03-01 09:00:00-07' + (w.n * interval '24 days') + (f.facility_id * interval '2 hours')
              + (CASE WHEN w.n % 10 = 0 THEN interval '6 hours' ELSE interval '2 days' END) END,
    CASE WHEN w.n % 10 = 0 THEN 'urgent' WHEN w.n % 5 = 0 THEN 'high'
         WHEN w.n % 3 = 0 THEN 'medium' ELSE 'low' END,
    (ARRAY['asset_condition', 'service_recovery', 'supply_request', 'safety_check', 'space_readiness'])[((w.n - 1) % 5) + 1],
    CASE WHEN w.n <= 18 THEN 'resolved' WHEN w.n = 19 THEN 'in_progress' ELSE 'assigned' END,
    CASE WHEN w.n <= 18 THEN (0.75 + (w.n % 8) * 0.50)::numeric(8,2) ELSE NULL END
FROM shared_facilities.facilities AS f
CROSS JOIN generate_series(1, 20) AS w(n);

INSERT INTO shared_workforce.shifts (
    employee_id, facility_id, service_visit_id, shift_start, shift_end,
    shift_status, paid_hours
)
SELECT
    ((v.service_visit_id + crew.n * 17 - 1) % 90) + 1,
    v.facility_id,
    v.service_visit_id,
    v.scheduled_start - interval '15 minutes',
    v.scheduled_end + interval '15 minutes',
    CASE WHEN v.visit_status = 'missed' THEN 'absent' ELSE 'complete' END,
    CASE WHEN v.visit_status = 'missed' THEN 0
         ELSE round((extract(epoch FROM (v.scheduled_end - v.scheduled_start)) / 3600.0 + 0.5)::numeric, 2) END
FROM shared_operations.service_visits AS v
CROSS JOIN generate_series(1, 2) AS crew(n);

INSERT INTO shared_quality.inspections (
    facility_id, service_visit_id, inspected_at, inspection_type, score,
    passed, inspector_role
)
SELECT
    v.facility_id,
    v.service_visit_id,
    v.scheduled_end + interval '45 minutes',
    CASE WHEN v.service_type_id IN (3, 8) THEN 'readiness_review' ELSE 'service_quality' END,
    (72 + ((v.facility_id * 5 + v.service_visit_id) % 29))::numeric(5,2),
    (72 + ((v.facility_id * 5 + v.service_visit_id) % 29)) >= 80,
    'Apex Quality Reviewer'
FROM shared_operations.service_visits AS v
WHERE v.service_visit_id % 2 = 0;

INSERT INTO shared_quality.inspection_findings (
    inspection_id, finding_category, severity, corrective_action, closed_at
)
SELECT
    i.inspection_id,
    (ARRAY['service_consistency', 'supply_readiness', 'asset_condition', 'documentation'])[((i.inspection_id - 1) % 4) + 1],
    CASE WHEN i.score < 76 THEN 'major' WHEN i.score < 82 THEN 'moderate' ELSE 'minor' END,
    CASE WHEN i.score < 80 THEN 'Complete corrective service and supervisor review'
         ELSE 'Record observation and verify during next inspection' END,
    CASE WHEN i.inspection_id % 7 = 0 THEN NULL ELSE i.inspected_at + interval '2 days' END
FROM shared_quality.inspections AS i
WHERE i.score < 90;

INSERT INTO shared_quality.service_feedback (
    client_id, facility_id, submitted_date, rating, feedback_category,
    response_days, synthetic_record
)
SELECT
    f.client_id,
    f.facility_id,
    date '2025-01-15' + (m.n * interval '45 days')::interval,
    3 + ((f.facility_id + m.n) % 3),
    (ARRAY['service_quality', 'readiness', 'communication', 'response_time'])[((f.facility_id + m.n - 1) % 4) + 1],
    (f.facility_id + m.n) % 5,
    true
FROM shared_facilities.facilities AS f
CROSS JOIN generate_series(0, 11) AS m(n);

INSERT INTO shared_supply.vendors (
    vendor_code, vendor_name, vendor_category, lead_time_days, active, synthetic_record
)
SELECT
    format('APX-VEN-%s', to_char(n, 'FM00')),
    format('Apex Supply Partner %s', to_char(n, 'FM00')),
    (ARRAY['consumables', 'equipment', 'parts', 'safety'])[((n - 1) % 4) + 1],
    2 + n * 2,
    true,
    true
FROM generate_series(1, 8) AS series(n);

INSERT INTO shared_supply.products (
    vendor_id, product_code, product_name, product_category,
    unit_of_measure, unit_cost, reorder_level
)
SELECT
    v.vendor_id,
    format('APX-PRD-%s-%s', to_char(v.vendor_id, 'FM00'), to_char(p.n, 'FM00')),
    format('Apex Facility Supply %s-%s', to_char(v.vendor_id, 'FM00'), to_char(p.n, 'FM00')),
    (ARRAY['consumable', 'replacement_part', 'safety_item', 'service_tool', 'sensor_supply'])[p.n],
    (ARRAY['case', 'unit', 'pack', 'unit', 'pack'])[p.n],
    (18 + v.vendor_id * 7 + p.n * 4.25)::numeric(10,2),
    (8 + v.vendor_id + p.n * 2)::numeric(12,2)
FROM shared_supply.vendors AS v
CROSS JOIN generate_series(1, 5) AS p(n);

INSERT INTO shared_supply.inventory_transactions (
    facility_id, product_id, transaction_date, transaction_type, quantity, reference_code
)
SELECT
    f.facility_id,
    ((f.facility_id * 7 + t.n * 3 - 1) % 40) + 1,
    date '2025-01-01' + (t.n * 5) + (f.facility_id % 5),
    CASE WHEN t.n % 15 = 0 THEN 'adjustment'
         WHEN t.n % 6 = 0 THEN 'receipt' ELSE 'usage' END,
    CASE WHEN t.n % 15 = 0 THEN -2
         WHEN t.n % 6 = 0 THEN 24 + (t.n % 12)
         ELSE -(1 + (t.n % 5)) END,
    format('APX-INV-%s-%s', to_char(f.facility_id, 'FM000'), to_char(t.n, 'FM000'))
FROM shared_facilities.facilities AS f
CROSS JOIN generate_series(1, 120) AS t(n);

INSERT INTO shared_finance.estimates (
    opportunity_id, facility_id, estimate_date, labour_cost, material_cost,
    overhead_cost, proposed_monthly_price
)
SELECT
    o.opportunity_id,
    o.opportunity_id,
    o.opened_date + 21,
    (7800 + o.opportunity_id * 240)::numeric(14,2),
    (1650 + o.opportunity_id * 65)::numeric(14,2),
    (2400 + o.opportunity_id * 90)::numeric(14,2),
    (14500 + o.opportunity_id * 525 + (o.opportunity_id % 4) * 900)::numeric(14,2)
FROM shared_crm.opportunities AS o;

INSERT INTO shared_finance.invoices (
    contract_id, invoice_number, invoice_date, due_date, subtotal, tax_amount,
    invoice_status, paid_date
)
SELECT
    c.contract_id,
    format('APX-INV-%s-%s', to_char(c.contract_id, 'FM000'), to_char(m.n, 'FM00')),
    (date '2025-01-01' + ((m.n - 1) * interval '1 month'))::date,
    (date '2025-01-01' + ((m.n - 1) * interval '1 month') + interval '30 days')::date,
    c.monthly_value,
    round(c.monthly_value * 0.05, 2),
    CASE WHEN m.n <= 18 THEN 'paid' WHEN m.n = 19 THEN 'issued' ELSE 'draft' END,
    CASE WHEN m.n <= 18
         THEN (date '2025-01-01' + ((m.n - 1) * interval '1 month') + interval '18 days')::date END
FROM shared_crm.contracts AS c
CROSS JOIN generate_series(1, 20) AS m(n);

INSERT INTO shared_finance.cost_entries (
    facility_id, service_visit_id, cost_date, cost_category, amount, source_system
)
SELECT
    v.facility_id,
    v.service_visit_id,
    v.scheduled_start::date,
    c.cost_category,
    CASE WHEN c.cost_category = 'labour'
         THEN round((v.planned_minutes / 60.0 * v.crew_size * 27.50)::numeric, 2)
         ELSE round((18 + v.service_type_id * 7 + (v.facility_id % 6) * 3)::numeric, 2) END,
    CASE WHEN c.cost_category = 'labour' THEN 'workforce_schedule' ELSE 'inventory_ledger' END
FROM shared_operations.service_visits AS v
CROSS JOIN (VALUES ('labour'), ('materials')) AS c(cost_category);

INSERT INTO shared_insights.monthly_operational_metrics (
    facility_id, metric_month, completed_visits, missed_visits, quality_score,
    labour_hours, operating_cost, client_rating
)
SELECT
    f.facility_id,
    (date '2025-01-01' + (m.n * interval '1 month'))::date,
    12 + ((f.facility_id + m.n) % 7),
    CASE WHEN (f.facility_id + m.n) % 9 = 0 THEN 1 ELSE 0 END,
    (78 + ((f.facility_id * 3 + m.n * 2) % 22))::numeric(5,2),
    (145 + f.facility_id * 1.8 + m.n * 2.4)::numeric(12,2),
    (9800 + f.facility_id * 315 + m.n * 125)::numeric(14,2),
    (3.20 + ((f.facility_id + m.n) % 18) / 10.0)::numeric(3,2)
FROM shared_facilities.facilities AS f
CROSS JOIN generate_series(0, 19) AS m(n);

INSERT INTO shared_insights.customer_segments (
    client_id, segment_name, annual_value_band, service_complexity,
    retention_risk, assigned_date
)
SELECT
    c.client_id,
    (ARRAY['growth', 'strategic', 'core'])[((c.client_id - 1) % 3) + 1],
    CASE WHEN c.client_id >= 9 THEN 'high' WHEN c.client_id >= 5 THEN 'medium' ELSE 'developing' END,
    (ARRAY['moderate', 'high', 'complex'])[((c.client_id - 1) % 3) + 1],
    CASE WHEN c.client_id % 6 = 0 THEN 'high' WHEN c.client_id % 4 = 0 THEN 'medium' ELSE 'low' END,
    date '2026-07-01'
FROM shared_facilities.clients AS c;

INSERT INTO shared_spatial.service_territories (
    territory_code, territory_name, service_region, boundary
)
SELECT
    format('APX-TER-%s', to_char(n, 'FM00')),
    format('Apex Service Territory %s', to_char(n, 'FM00')),
    format('Apex Region %s', to_char(((n - 1) / 2) + 1, 'FM00')),
    ST_MakeEnvelope(
        -114.80 + ((n - 1) % 3) * 0.60,
        52.80 + ((n - 1) / 3) * 0.60,
        -114.28 + ((n - 1) % 3) * 0.60,
        53.32 + ((n - 1) / 3) * 0.60,
        4326
    )
FROM generate_series(1, 6) AS series(n);

INSERT INTO shared_spatial.route_events (
    facility_id, service_visit_id, territory_id, event_time, event_type, location
)
SELECT
    v.facility_id,
    v.service_visit_id,
    ((v.facility_id - 1) % 6) + 1,
    CASE WHEN e.n = 1 THEN v.scheduled_start - interval '30 minutes'
         WHEN e.n = 2 THEN v.scheduled_start - interval '5 minutes'
         WHEN e.n = 3 THEN v.scheduled_start
         ELSE v.scheduled_end END,
    (ARRAY['departed', 'arrived', 'service_started', 'service_completed'])[e.n],
    ST_SetSRID(ST_MakePoint(
        -114.68 + (((v.facility_id - 1) % 3) * 0.60) + ((v.facility_id % 7) * 0.045) + (e.n * 0.001),
        52.92 + ((((v.facility_id - 1) % 6) / 3) * 0.60) + ((v.facility_id % 5) * 0.055) + (e.n * 0.001)
    ), 4326)
FROM shared_operations.service_visits AS v
CROSS JOIN generate_series(1, 4) AS e(n);

INSERT INTO shared_research.dataset_catalog (
    dataset_code, dataset_title, source_type, source_url, licence_name,
    licence_url, version_label, acquired_date, contains_personal_information,
    permitted_use, quality_notes, attribution_text
)
VALUES
    ('APX-FACILITIES-V1', 'Apex Facilities and Spaces', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Deterministic fictional records; validate assumptions before analysis.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-CRM-V1', 'Apex Client, Opportunity, and Contract History', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Values support joins and commercial analysis but do not represent real organizations.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-READINESS-V1', 'Apex Mobilization and Readiness Tasks', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Task progress and risk signals are intentionally varied for exercises.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-OPERATIONS-V1', 'Apex Service Visits and Work Orders', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Operational events cover recurring and responsive facility services.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-WORKFORCE-V1', 'Apex Workforce, Skills, and Shifts', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Display names are numbered synthetic roles, not people.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-QUALITY-V1', 'Apex Inspections, Findings, and Feedback', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Quality variation is deterministic and intended for trend analysis.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-ASSETS-V1', 'Apex Assets, Maintenance, and Sensor Readings', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Sensor readings are generated signals and are not equipment telemetry.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-SUPPLY-V1', 'Apex Products and Inventory Movements', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Products and vendors are fictional and numbered.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-FINANCE-V1', 'Apex Estimates, Invoices, and Operating Costs', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Financial values are fictional and not accounting records.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-INSIGHTS-V1', 'Apex Operational Metrics and Customer Segments', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Metrics are deterministic aggregates for analytics practice.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-SPATIAL-V1', 'Apex Territories and Route Events', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Coordinates are fictional and do not identify customer sites.', 'Synthetic learning data created for the fictional Apex Facilities Platform.'),
    ('APX-RESEARCH-V1', 'Apex External Observation Sandbox', 'synthetic', NULL, 'Apex Synthetic Learning Data Licence', NULL, '2026.1', date '2026-08-12', false, 'Teaching, learning, demonstration, and portfolio practice.', 'Observations imitate research measures without copying an external dataset.', 'Synthetic learning data created for the fictional Apex Facilities Platform.');

INSERT INTO shared_research.external_observations (
    dataset_id, observed_date, geography_code, measure_name,
    measure_value, measure_unit, quality_flag
)
SELECT
    d.dataset_id,
    date '2024-01-01' + (o.n * 5),
    format('APX-GEO-%s', to_char(((o.n - 1) % 9) + 1, 'FM00')),
    CASE WHEN d.dataset_id % 3 = 1 THEN 'demand_index'
         WHEN d.dataset_id % 3 = 2 THEN 'cost_index'
         ELSE 'readiness_index' END,
    (50 + d.dataset_id * 2.5 + ((o.n * 7 + d.dataset_id * 3) % 450) / 10.0)::numeric(16,4),
    'index',
    CASE WHEN (o.n + d.dataset_id) % 47 = 0 THEN 'suppressed'
         WHEN (o.n + d.dataset_id) % 19 = 0 THEN 'estimated'
         ELSE 'valid' END
FROM shared_research.dataset_catalog AS d
CROSS JOIN generate_series(1, 120) AS o(n);

INSERT INTO shared_research.data_packages (
    package_code, package_title, course_code, lab_number, package_version,
    release_status, learning_purpose, dataset_ids, released_at
)
VALUES
    ('AIDA1145-LAB01', 'Explore the Apex Data Platform', 'AIDA 1145', 1, '2026.1', 'validated', 'Connect safely, navigate schemas, inspect metadata, and profile facility records.', ARRAY[1, 2], NULL),
    ('AIDA1145-LAB02', 'Design Reliable Apex Tables', 'AIDA 1145', 2, '2026.1', 'validated', 'Create workspace tables with suitable types, keys, constraints, and documentation.', ARRAY[1, 2, 3], NULL),
    ('AIDA1145-LAB03', 'Query Connected Facility Operations', 'AIDA 1145', 3, '2026.1', 'validated', 'Use joins, filters, grouping, and subqueries across connected operational domains.', ARRAY[1, 2, 4, 5], NULL),
    ('AIDA1145-LAB04', 'Build a Repeatable Data Ingestion', 'AIDA 1145', 4, '2026.1', 'validated', 'Load a versioned Apex extract into a student workspace with validation and rerun safety.', ARRAY[4, 7, 8], NULL),
    ('AIDA1145-LAB05', 'Improve Facility Data Quality', 'AIDA 1145', 5, '2026.1', 'validated', 'Detect, document, and repair data-quality issues while preserving lineage.', ARRAY[3, 4, 6, 8], NULL),
    ('AIDA1145-LAB06', 'Transform Operations into Analytics Data', 'AIDA 1145', 6, '2026.1', 'validated', 'Create tested transformations for service, quality, cost, and asset analysis.', ARRAY[4, 6, 7, 9], NULL),
    ('AIDA1145-LAB07', 'Orchestrate an Apex Data Pipeline', 'AIDA 1145', 7, '2026.1', 'validated', 'Run an observable multi-step pipeline with logging, checkpoints, and failure handling.', ARRAY[4, 5, 7, 8], NULL),
    ('AIDA1145-LAB08', 'Model an Apex Analytics Warehouse', 'AIDA 1145', 8, '2026.1', 'validated', 'Design and populate dimensions and facts for facility performance reporting.', ARRAY[1, 2, 4, 5, 6, 7, 8, 9], NULL),
    ('AIDA1145-LAB09', 'Serve Trusted Apex Metrics', 'AIDA 1145', 9, '2026.1', 'validated', 'Publish governed analytical outputs for a Streamlit decision-support page.', ARRAY[6, 7, 9, 10], NULL),
    ('AIDA1145-LAB10', 'Integrate the Apex Data Product', 'AIDA 1145', 10, '2026.1', 'validated', 'Integrate ingestion, quality, transformation, storage, testing, and presentation into a documented data product.', ARRAY[1,2,3,4,5,6,7,8,9,10,11,12], NULL);

COMMIT;
