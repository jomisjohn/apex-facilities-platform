$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"
$repoRoot = Split-Path $PSScriptRoot -Parent
$service = 'database'
$database = 'apex_facilities'
$adminUser = 'apex_admin'

function Invoke-DbQuery {
    param(
        [Parameter(Mandatory = $true)][string]$Sql,
        [switch]$AllowFailure
    )

    $previousErrorAction = $ErrorActionPreference
    if ($AllowFailure) { $ErrorActionPreference = 'Continue' }
    try {
        $result = @(& $docker compose --project-directory $repoRoot exec --no-TTY $service psql `
            --username $adminUser `
            --dbname $database `
            --no-psqlrc `
            --quiet `
            --tuples-only `
            --no-align `
            --field-separator '|' `
            --set ON_ERROR_STOP=1 `
            --command $Sql 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }

    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "Database validation query failed: $($result -join ' ')"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines = @($result | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' })
    }
}

function Assert-Zero {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Sql
    )

    $result = Invoke-DbQuery -Sql $Sql
    $value = if ($result.Lines.Count -eq 0) { '' } else { $result.Lines[-1] }
    if ($value -ne '0') { throw "$Name failed ($value issue(s))." }
}

$runningServices = @(& $docker compose --project-directory $repoRoot ps --status running --services)
if ($runningServices -notcontains $service) { throw 'Database service is not running.' }
& $docker compose --project-directory $repoRoot exec --no-TTY $service pg_isready --username $adminUser --dbname $database | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Database service is not ready.' }

# This is the single release-volume map. Raise a minimum when a published data
# package grows; add each new base table here when the platform schema expands.
$minimumRows = [ordered]@{
    'shared_facilities.clients'                    = 12
    'shared_facilities.facilities'                 = 36
    'shared_facilities.spaces'                     = 200
    'shared_crm.opportunities'                     = 36
    'shared_crm.contracts'                         = 33
    'shared_readiness.mobilizations'               = 33
    'shared_readiness.readiness_tasks'             = 250
    'shared_workforce.employees'                   = 90
    'shared_workforce.employee_skills'             = 270
    'shared_assets.asset_types'                    = 10
    'shared_assets.assets'                         = 360
    'shared_assets.maintenance_plans'              = 360
    'shared_assets.maintenance_events'             = 1400
    'shared_assets.sensor_readings'                = 17000
    'shared_operations.service_types'              = 8
    'shared_operations.service_visits'             = 2300
    'shared_operations.work_orders'                = 700
    'shared_workforce.shifts'                      = 4700
    'shared_quality.inspections'                   = 1100
    'shared_quality.inspection_findings'           = 700
    'shared_quality.service_feedback'              = 400
    'shared_supply.vendors'                        = 8
    'shared_supply.products'                       = 40
    'shared_supply.inventory_transactions'         = 4000
    'shared_finance.estimates'                     = 36
    'shared_finance.invoices'                      = 650
    'shared_finance.cost_entries'                  = 4700
    'shared_insights.monthly_operational_metrics'  = 700
    'shared_insights.customer_segments'            = 12
    'shared_spatial.service_territories'            = 6
    'shared_spatial.route_events'                   = 9500
    'shared_research.dataset_catalog'              = 12
    'shared_research.data_packages'                = 10
    'shared_research.external_observations'         = 1400
}

$expectedTablesSql = ($minimumRows.Keys | ForEach-Object {
    $parts = $_.Split('.')
    "('$($parts[0])','$($parts[1])')"
}) -join ",`n"

$missingTables = Invoke-DbQuery -Sql @"
WITH expected(schema_name, table_name) AS (
    VALUES $expectedTablesSql
)
SELECT schema_name || '.' || table_name
FROM expected
WHERE to_regclass(format('%I.%I', schema_name, table_name)) IS NULL
ORDER BY 1;
"@
if ($missingTables.Lines.Count -gt 0) {
    throw "Missing required table(s): $($missingTables.Lines -join ', ')."
}

$rowCountSql = ($minimumRows.GetEnumerator() | ForEach-Object {
    "SELECT '$($_.Key)' AS table_name, count(*)::bigint AS row_count, $($_.Value)::bigint AS minimum_rows FROM $($_.Key)"
}) -join "`nUNION ALL`n"
$lowVolume = Invoke-DbQuery -Sql @"
WITH row_counts AS (
$rowCountSql
)
SELECT table_name || ' (' || row_count || '/' || minimum_rows || ')'
FROM row_counts
WHERE row_count < minimum_rows
ORDER BY table_name;
"@
if ($lowVolume.Lines.Count -gt 0) {
    $preview = @($lowVolume.Lines | Select-Object -First 6)
    $remaining = $lowVolume.Lines.Count - $preview.Count
    $suffix = if ($remaining -gt 0) { "; plus $remaining more" } else { '' }
    throw "Data volume below release minimum in $($lowVolume.Lines.Count) table(s): $($preview -join ', ')$suffix."
}

Assert-Zero -Name 'Foreign-key validation' -Sql @"
SELECT count(*)
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname LIKE 'shared\_%' ESCAPE '\'
  AND c.contype = 'f'
  AND NOT c.convalidated;
"@

Assert-Zero -Name 'Cross-domain relationship integrity' -Sql @"
SELECT
    (SELECT count(*) FROM shared_crm.contracts c
      JOIN shared_facilities.facilities f USING (facility_id)
      WHERE c.client_id <> f.client_id)
  + (SELECT count(*) FROM shared_operations.service_visits v
      JOIN shared_crm.contracts c USING (contract_id)
      WHERE v.facility_id <> c.facility_id)
  + (SELECT count(*) FROM shared_operations.work_orders w
      JOIN shared_assets.assets a USING (asset_id)
      WHERE w.facility_id <> a.facility_id)
  + (SELECT count(*) FROM shared_workforce.shifts s
      JOIN shared_operations.service_visits v USING (service_visit_id)
      WHERE s.facility_id <> v.facility_id)
  + (SELECT count(*) FROM shared_quality.inspections i
      JOIN shared_operations.service_visits v USING (service_visit_id)
      WHERE i.facility_id <> v.facility_id)
  + (SELECT count(*) FROM shared_quality.service_feedback f
      JOIN shared_facilities.facilities x USING (facility_id)
      WHERE f.client_id <> x.client_id)
  + (SELECT count(*) FROM shared_spatial.route_events r
      JOIN shared_operations.service_visits v USING (service_visit_id)
      WHERE r.facility_id <> v.facility_id);
"@

Assert-Zero -Name 'Synthetic-data privacy flags' -Sql @"
SELECT
    (SELECT count(*) FROM shared_facilities.clients WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_facilities.facilities WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_crm.opportunities WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_crm.contracts WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_workforce.employees WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_assets.assets WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_quality.service_feedback WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_supply.vendors WHERE NOT synthetic_record)
  + (SELECT count(*) FROM shared_research.dataset_catalog
      WHERE contains_personal_information OR source_type <> 'synthetic');
"@

Assert-Zero -Name 'Dataset provenance and licence metadata' -Sql @"
SELECT count(*)
FROM shared_research.dataset_catalog
WHERE btrim(dataset_code) = ''
   OR btrim(dataset_title) = ''
   OR btrim(licence_name) = ''
   OR btrim(version_label) = ''
   OR btrim(permitted_use) = ''
   OR btrim(quality_notes) = ''
   OR btrim(attribution_text) = ''
   OR (source_type = 'open_data' AND (source_url IS NULL OR licence_url IS NULL));
"@

Assert-Zero -Name 'Data-package dataset references' -Sql @"
SELECT count(*)
FROM shared_research.data_packages p
WHERE cardinality(p.dataset_ids) = 0
   OR btrim(p.package_version) = ''
   OR btrim(p.learning_purpose) = ''
   OR (p.release_status = 'released' AND p.released_at IS NULL)
   OR EXISTS (
        SELECT 1
        FROM unnest(p.dataset_ids) AS referenced(dataset_id)
        LEFT JOIN shared_research.dataset_catalog d ON d.dataset_id = referenced.dataset_id
        WHERE d.dataset_id IS NULL
   );
"@

Assert-Zero -Name 'Spatial geometry validity' -Sql @"
SELECT
    (SELECT count(*) FROM shared_spatial.service_territories
      WHERE boundary IS NULL OR ST_IsEmpty(boundary) OR NOT ST_IsValid(boundary) OR ST_SRID(boundary) <> 4326)
  + (SELECT count(*) FROM shared_spatial.route_events
      WHERE location IS NULL OR ST_IsEmpty(location) OR NOT ST_IsValid(location) OR ST_SRID(location) <> 4326);
"@

Assert-Zero -Name 'Shared-schema privilege boundary' -Sql @"
SELECT count(*)
FROM information_schema.tables t
WHERE t.table_schema LIKE 'shared\_%' ESCAPE '\'
  AND t.table_type = 'BASE TABLE'
  AND (
       NOT has_table_privilege('apex_shared_reader', format('%I.%I', t.table_schema, t.table_name), 'SELECT')
       OR has_table_privilege('apex_shared_reader', format('%I.%I', t.table_schema, t.table_name), 'INSERT')
       OR has_table_privilege('apex_shared_reader', format('%I.%I', t.table_schema, t.table_name), 'UPDATE')
       OR has_table_privilege('apex_shared_reader', format('%I.%I', t.table_schema, t.table_name), 'DELETE')
  );
"@

Assert-Zero -Name 'Shared-schema CREATE boundary' -Sql @"
SELECT count(*)
FROM pg_namespace
WHERE nspname LIKE 'shared\_%' ESCAPE '\'
  AND (
       has_schema_privilege('apex_shared_reader', oid, 'CREATE')
       OR has_schema_privilege('apex_workspace_member', oid, 'CREATE')
       OR has_schema_privilege('public', oid, 'CREATE')
  );
"@

$validationRole = 'apex_validation_student'
$workspaceSchema = 'workspace_validation_student'
$peerSchema = 'workspace_validation_peer'
$cleanupSql = @"
SET client_min_messages TO warning;
DROP SCHEMA IF EXISTS $workspaceSchema CASCADE;
DROP SCHEMA IF EXISTS $peerSchema CASCADE;
DROP ROLE IF EXISTS $validationRole;
"@

try {
    Invoke-DbQuery -Sql $cleanupSql | Out-Null
    Invoke-DbQuery -Sql @"
CREATE ROLE $validationRole NOLOGIN;
GRANT apex_shared_reader, apex_workspace_member TO $validationRole;
CREATE SCHEMA $workspaceSchema AUTHORIZATION $validationRole;
CREATE SCHEMA $peerSchema;
REVOKE ALL ON SCHEMA $peerSchema FROM PUBLIC;
CREATE TABLE $peerSchema.private_result (result_id integer PRIMARY KEY);
SET ROLE $validationRole;
CREATE TABLE $workspaceSchema.student_result (result_id integer PRIMARY KEY, result_text text NOT NULL);
INSERT INTO $workspaceSchema.student_result VALUES (1, 'workspace-write-ok');
UPDATE $workspaceSchema.student_result SET result_text = 'workspace-update-ok' WHERE result_id = 1;
DELETE FROM $workspaceSchema.student_result WHERE result_id = 1;
RESET ROLE;
"@ | Out-Null

    $sharedWrite = Invoke-DbQuery -AllowFailure -Sql "SET ROLE $validationRole; INSERT INTO shared_facilities.clients (client_code, client_name, sector, relationship_start, status) VALUES ('VALIDATION-ONLY', 'Validation Only', 'office', current_date, 'prospect');"
    if ($sharedWrite.ExitCode -eq 0) { throw 'Workspace user unexpectedly wrote to shared data.' }

    $peerRead = Invoke-DbQuery -AllowFailure -Sql "SET ROLE $validationRole; SELECT count(*) FROM $peerSchema.private_result;"
    if ($peerRead.ExitCode -eq 0) { throw 'Workspace user unexpectedly read a peer workspace.' }
}
finally {
    Invoke-DbQuery -Sql $cleanupSql | Out-Null
}

Write-Host "PASS: 34 tables; release volumes; relationships; synthetic privacy; provenance; PostGIS; shared read-only access; isolated writable workspace."
