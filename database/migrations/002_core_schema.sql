BEGIN;

CREATE TABLE shared_facilities.clients (
    client_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_code text NOT NULL UNIQUE,
    client_name text NOT NULL,
    sector text NOT NULL CHECK (sector IN ('education', 'healthcare', 'office', 'retail', 'industrial', 'public')),
    relationship_start date NOT NULL,
    status text NOT NULL CHECK (status IN ('prospect', 'active', 'paused', 'closed')),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_facilities.facilities (
    facility_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id integer NOT NULL REFERENCES shared_facilities.clients(client_id),
    facility_code text NOT NULL UNIQUE,
    facility_name text NOT NULL,
    facility_type text NOT NULL,
    city text NOT NULL,
    province_code char(2) NOT NULL DEFAULT 'AB',
    floor_area_m2 numeric(12,2) NOT NULL CHECK (floor_area_m2 > 0),
    opened_year integer CHECK (opened_year BETWEEN 1950 AND 2030),
    operating_status text NOT NULL CHECK (operating_status IN ('active', 'mobilizing', 'inactive')),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_facilities.spaces (
    space_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    space_code text NOT NULL,
    space_type text NOT NULL,
    floor_level integer NOT NULL,
    area_m2 numeric(10,2) NOT NULL CHECK (area_m2 > 0),
    service_priority smallint NOT NULL CHECK (service_priority BETWEEN 1 AND 5),
    UNIQUE (facility_id, space_code)
);

CREATE TABLE shared_crm.opportunities (
    opportunity_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id integer NOT NULL REFERENCES shared_facilities.clients(client_id),
    opened_date date NOT NULL,
    stage text NOT NULL CHECK (stage IN ('discovery', 'assessment', 'proposal', 'negotiation', 'won', 'lost')),
    source_channel text NOT NULL,
    estimated_annual_value numeric(14,2) NOT NULL CHECK (estimated_annual_value >= 0),
    win_probability numeric(5,4) NOT NULL CHECK (win_probability BETWEEN 0 AND 1),
    expected_close_date date NOT NULL,
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_crm.contracts (
    contract_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id integer NOT NULL REFERENCES shared_facilities.clients(client_id),
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    contract_code text NOT NULL UNIQUE,
    start_date date NOT NULL,
    end_date date NOT NULL CHECK (end_date > start_date),
    monthly_value numeric(14,2) NOT NULL CHECK (monthly_value > 0),
    service_level text NOT NULL CHECK (service_level IN ('standard', 'enhanced', 'critical')),
    status text NOT NULL CHECK (status IN ('draft', 'mobilizing', 'active', 'expired', 'terminated')),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_readiness.mobilizations (
    mobilization_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_id integer NOT NULL UNIQUE REFERENCES shared_crm.contracts(contract_id),
    planned_start_date date NOT NULL,
    go_live_date date,
    status text NOT NULL CHECK (status IN ('planned', 'in_progress', 'ready', 'delayed', 'complete')),
    readiness_score numeric(5,2) NOT NULL CHECK (readiness_score BETWEEN 0 AND 100),
    risk_level text NOT NULL CHECK (risk_level IN ('low', 'medium', 'high'))
);

CREATE TABLE shared_readiness.readiness_tasks (
    readiness_task_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mobilization_id integer NOT NULL REFERENCES shared_readiness.mobilizations(mobilization_id),
    task_type text NOT NULL,
    owner_role text NOT NULL,
    due_date date NOT NULL,
    completed_date date,
    status text NOT NULL CHECK (status IN ('not_started', 'in_progress', 'blocked', 'complete')),
    CHECK (completed_date IS NULL OR completed_date >= due_date - 60)
);

CREATE TABLE shared_workforce.employees (
    employee_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_code text NOT NULL UNIQUE,
    display_name text NOT NULL,
    role_name text NOT NULL,
    hire_date date NOT NULL,
    employment_status text NOT NULL CHECK (employment_status IN ('active', 'leave', 'inactive')),
    hourly_cost numeric(8,2) NOT NULL CHECK (hourly_cost > 0),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_workforce.employee_skills (
    employee_id integer NOT NULL REFERENCES shared_workforce.employees(employee_id),
    skill_code text NOT NULL,
    proficiency_level smallint NOT NULL CHECK (proficiency_level BETWEEN 1 AND 5),
    certified_until date,
    PRIMARY KEY (employee_id, skill_code)
);

CREATE TABLE shared_assets.asset_types (
    asset_type_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_type_code text NOT NULL UNIQUE,
    asset_type_name text NOT NULL,
    category text NOT NULL,
    expected_life_years integer NOT NULL CHECK (expected_life_years BETWEEN 1 AND 50),
    criticality_default smallint NOT NULL CHECK (criticality_default BETWEEN 1 AND 5)
);

CREATE TABLE shared_assets.assets (
    asset_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    asset_type_id integer NOT NULL REFERENCES shared_assets.asset_types(asset_type_id),
    asset_code text NOT NULL UNIQUE,
    installed_date date NOT NULL,
    condition_score numeric(4,2) NOT NULL CHECK (condition_score BETWEEN 0 AND 5),
    criticality smallint NOT NULL CHECK (criticality BETWEEN 1 AND 5),
    operating_status text NOT NULL CHECK (operating_status IN ('active', 'degraded', 'offline', 'retired')),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_assets.maintenance_plans (
    maintenance_plan_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id integer NOT NULL REFERENCES shared_assets.assets(asset_id),
    task_name text NOT NULL,
    frequency_days integer NOT NULL CHECK (frequency_days BETWEEN 1 AND 730),
    estimated_minutes integer NOT NULL CHECK (estimated_minutes > 0),
    last_completed_date date,
    next_due_date date NOT NULL
);

CREATE TABLE shared_assets.maintenance_events (
    maintenance_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id integer NOT NULL REFERENCES shared_assets.assets(asset_id),
    event_date date NOT NULL,
    event_type text NOT NULL CHECK (event_type IN ('preventive', 'corrective', 'inspection', 'failure')),
    downtime_minutes integer NOT NULL DEFAULT 0 CHECK (downtime_minutes >= 0),
    labour_hours numeric(8,2) NOT NULL CHECK (labour_hours >= 0),
    material_cost numeric(12,2) NOT NULL CHECK (material_cost >= 0),
    outcome text NOT NULL
);

CREATE TABLE shared_assets.sensor_readings (
    sensor_reading_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id integer NOT NULL REFERENCES shared_assets.assets(asset_id),
    observed_at timestamptz NOT NULL,
    metric_name text NOT NULL,
    metric_value numeric(14,4) NOT NULL,
    metric_unit text NOT NULL,
    quality_flag text NOT NULL CHECK (quality_flag IN ('valid', 'estimated', 'suspect')),
    UNIQUE (asset_id, observed_at, metric_name)
);

CREATE TABLE shared_operations.service_types (
    service_type_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_code text NOT NULL UNIQUE,
    service_name text NOT NULL,
    service_category text NOT NULL,
    standard_minutes integer NOT NULL CHECK (standard_minutes > 0),
    standard_unit_cost numeric(10,2) NOT NULL CHECK (standard_unit_cost >= 0)
);

CREATE TABLE shared_operations.service_visits (
    service_visit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_id integer NOT NULL REFERENCES shared_crm.contracts(contract_id),
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    service_type_id integer NOT NULL REFERENCES shared_operations.service_types(service_type_id),
    scheduled_start timestamptz NOT NULL,
    scheduled_end timestamptz NOT NULL,
    actual_start timestamptz,
    actual_end timestamptz,
    visit_status text NOT NULL CHECK (visit_status IN ('scheduled', 'in_progress', 'complete', 'cancelled', 'missed')),
    crew_size smallint NOT NULL CHECK (crew_size BETWEEN 1 AND 20),
    planned_minutes integer NOT NULL CHECK (planned_minutes > 0),
    actual_minutes integer CHECK (actual_minutes >= 0),
    CHECK (scheduled_end > scheduled_start),
    CHECK (actual_end IS NULL OR actual_start IS NOT NULL)
);

CREATE TABLE shared_operations.work_orders (
    work_order_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    asset_id integer REFERENCES shared_assets.assets(asset_id),
    service_visit_id bigint REFERENCES shared_operations.service_visits(service_visit_id),
    created_at timestamptz NOT NULL,
    due_at timestamptz NOT NULL,
    resolved_at timestamptz,
    priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    category text NOT NULL,
    status text NOT NULL CHECK (status IN ('open', 'assigned', 'in_progress', 'resolved', 'cancelled')),
    labour_hours numeric(8,2) CHECK (labour_hours >= 0),
    CHECK (due_at >= created_at),
    CHECK (resolved_at IS NULL OR resolved_at >= created_at)
);

CREATE TABLE shared_workforce.shifts (
    shift_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id integer NOT NULL REFERENCES shared_workforce.employees(employee_id),
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    service_visit_id bigint REFERENCES shared_operations.service_visits(service_visit_id),
    shift_start timestamptz NOT NULL,
    shift_end timestamptz NOT NULL,
    shift_status text NOT NULL CHECK (shift_status IN ('scheduled', 'complete', 'absent', 'cancelled')),
    paid_hours numeric(6,2) NOT NULL CHECK (paid_hours >= 0),
    CHECK (shift_end > shift_start)
);

CREATE TABLE shared_quality.inspections (
    inspection_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    service_visit_id bigint REFERENCES shared_operations.service_visits(service_visit_id),
    inspected_at timestamptz NOT NULL,
    inspection_type text NOT NULL,
    score numeric(5,2) NOT NULL CHECK (score BETWEEN 0 AND 100),
    passed boolean NOT NULL,
    inspector_role text NOT NULL
);

CREATE TABLE shared_quality.inspection_findings (
    finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inspection_id bigint NOT NULL REFERENCES shared_quality.inspections(inspection_id),
    finding_category text NOT NULL,
    severity text NOT NULL CHECK (severity IN ('minor', 'moderate', 'major', 'critical')),
    corrective_action text NOT NULL,
    closed_at timestamptz
);

CREATE TABLE shared_quality.service_feedback (
    feedback_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id integer NOT NULL REFERENCES shared_facilities.clients(client_id),
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    submitted_date date NOT NULL,
    rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    feedback_category text NOT NULL,
    response_days integer CHECK (response_days >= 0),
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_supply.vendors (
    vendor_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_code text NOT NULL UNIQUE,
    vendor_name text NOT NULL,
    vendor_category text NOT NULL,
    lead_time_days integer NOT NULL CHECK (lead_time_days >= 0),
    active boolean NOT NULL DEFAULT true,
    synthetic_record boolean NOT NULL DEFAULT true
);

CREATE TABLE shared_supply.products (
    product_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id integer NOT NULL REFERENCES shared_supply.vendors(vendor_id),
    product_code text NOT NULL UNIQUE,
    product_name text NOT NULL,
    product_category text NOT NULL,
    unit_of_measure text NOT NULL,
    unit_cost numeric(10,2) NOT NULL CHECK (unit_cost >= 0),
    reorder_level numeric(12,2) NOT NULL CHECK (reorder_level >= 0)
);

CREATE TABLE shared_supply.inventory_transactions (
    inventory_transaction_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    product_id integer NOT NULL REFERENCES shared_supply.products(product_id),
    transaction_date date NOT NULL,
    transaction_type text NOT NULL CHECK (transaction_type IN ('receipt', 'usage', 'adjustment', 'transfer')),
    quantity numeric(12,2) NOT NULL CHECK (quantity <> 0),
    reference_code text NOT NULL
);

CREATE TABLE shared_finance.estimates (
    estimate_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    opportunity_id integer NOT NULL REFERENCES shared_crm.opportunities(opportunity_id),
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    estimate_date date NOT NULL,
    labour_cost numeric(14,2) NOT NULL CHECK (labour_cost >= 0),
    material_cost numeric(14,2) NOT NULL CHECK (material_cost >= 0),
    overhead_cost numeric(14,2) NOT NULL CHECK (overhead_cost >= 0),
    proposed_monthly_price numeric(14,2) NOT NULL CHECK (proposed_monthly_price > 0)
);

CREATE TABLE shared_finance.invoices (
    invoice_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_id integer NOT NULL REFERENCES shared_crm.contracts(contract_id),
    invoice_number text NOT NULL UNIQUE,
    invoice_date date NOT NULL,
    due_date date NOT NULL,
    subtotal numeric(14,2) NOT NULL CHECK (subtotal >= 0),
    tax_amount numeric(14,2) NOT NULL CHECK (tax_amount >= 0),
    invoice_status text NOT NULL CHECK (invoice_status IN ('draft', 'issued', 'paid', 'overdue', 'void')),
    paid_date date,
    CHECK (due_date >= invoice_date)
);

CREATE TABLE shared_finance.cost_entries (
    cost_entry_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    service_visit_id bigint REFERENCES shared_operations.service_visits(service_visit_id),
    cost_date date NOT NULL,
    cost_category text NOT NULL,
    amount numeric(14,2) NOT NULL CHECK (amount >= 0),
    source_system text NOT NULL
);

CREATE TABLE shared_insights.monthly_operational_metrics (
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    metric_month date NOT NULL,
    completed_visits integer NOT NULL CHECK (completed_visits >= 0),
    missed_visits integer NOT NULL CHECK (missed_visits >= 0),
    quality_score numeric(5,2) CHECK (quality_score BETWEEN 0 AND 100),
    labour_hours numeric(12,2) NOT NULL CHECK (labour_hours >= 0),
    operating_cost numeric(14,2) NOT NULL CHECK (operating_cost >= 0),
    client_rating numeric(3,2) CHECK (client_rating BETWEEN 1 AND 5),
    PRIMARY KEY (facility_id, metric_month)
);

CREATE TABLE shared_insights.customer_segments (
    client_id integer PRIMARY KEY REFERENCES shared_facilities.clients(client_id),
    segment_name text NOT NULL,
    annual_value_band text NOT NULL,
    service_complexity text NOT NULL,
    retention_risk text NOT NULL CHECK (retention_risk IN ('low', 'medium', 'high')),
    assigned_date date NOT NULL
);

CREATE TABLE shared_spatial.service_territories (
    territory_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    territory_code text NOT NULL UNIQUE,
    territory_name text NOT NULL,
    service_region text NOT NULL,
    boundary geometry(Polygon, 4326) NOT NULL
);

CREATE INDEX service_territories_boundary_gix
    ON shared_spatial.service_territories USING gist (boundary);

CREATE TABLE shared_spatial.route_events (
    route_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id integer NOT NULL REFERENCES shared_facilities.facilities(facility_id),
    service_visit_id bigint REFERENCES shared_operations.service_visits(service_visit_id),
    territory_id integer NOT NULL REFERENCES shared_spatial.service_territories(territory_id),
    event_time timestamptz NOT NULL,
    event_type text NOT NULL CHECK (event_type IN ('departed', 'arrived', 'service_started', 'service_completed')),
    location geometry(Point, 4326) NOT NULL
);

CREATE INDEX route_events_location_gix
    ON shared_spatial.route_events USING gist (location);

CREATE TABLE shared_research.dataset_catalog (
    dataset_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dataset_code text NOT NULL UNIQUE,
    dataset_title text NOT NULL,
    source_type text NOT NULL CHECK (source_type IN ('synthetic', 'open_data', 'student_import')),
    source_url text,
    licence_name text NOT NULL,
    licence_url text,
    version_label text NOT NULL,
    acquired_date date NOT NULL,
    contains_personal_information boolean NOT NULL DEFAULT false,
    permitted_use text NOT NULL,
    quality_notes text NOT NULL,
    attribution_text text NOT NULL
);

CREATE TABLE shared_research.data_packages (
    data_package_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    package_code text NOT NULL UNIQUE,
    package_title text NOT NULL,
    course_code text,
    lab_number smallint CHECK (lab_number BETWEEN 1 AND 20),
    package_version text NOT NULL,
    release_status text NOT NULL CHECK (release_status IN ('planned', 'draft', 'validated', 'released', 'retired')),
    learning_purpose text NOT NULL,
    dataset_ids integer[] NOT NULL DEFAULT '{}',
    released_at timestamptz
);

CREATE TABLE shared_research.external_observations (
    observation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dataset_id integer NOT NULL REFERENCES shared_research.dataset_catalog(dataset_id),
    observed_date date NOT NULL,
    geography_code text,
    measure_name text NOT NULL,
    measure_value numeric(16,4) NOT NULL,
    measure_unit text NOT NULL,
    quality_flag text NOT NULL CHECK (quality_flag IN ('valid', 'estimated', 'suppressed'))
);

GRANT SELECT ON ALL TABLES IN SCHEMA
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
TO apex_shared_reader;

COMMIT;
