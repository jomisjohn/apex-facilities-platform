$ErrorActionPreference = 'Stop'
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"
$container = 'apex-db'
$database = 'apex_facilities'
$adminUser = 'apex_admin'

$health = 'unknown'
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $health = (& $docker inspect $container --format '{{.State.Health.Status}}').Trim()
    if ($health -in @('healthy', 'unhealthy')) { break }
    Start-Sleep -Seconds 2
}
if ($health -ne 'healthy') { throw "Container health is $health." }

$databasePassword = & $docker exec $container sh -c 'printf %s "$POSTGRES_PASSWORD"'
if ($databasePassword.Length -lt 24) { throw 'Local database administrator password is shorter than 24 characters.' }

$tcpAuth = (& $docker exec -e "PGPASSWORD=$databasePassword" $container psql --host 127.0.0.1 --username $adminUser --dbname $database --tuples-only --no-align --no-psqlrc --command 'SELECT 1;').Trim()
if ($tcpAuth -ne '1') { throw 'Password-authenticated TCP connection failed.' }

$serverVersion = (& $docker exec $container psql -U $adminUser -d $database -Atc 'SHOW server_version;').Trim()
$postgisVersion = (& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT extversion FROM pg_extension WHERE extname='postgis';").Trim()
$schemaCount = [int](& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT count(*) FROM information_schema.schemata WHERE schema_name LIKE 'shared_%';")
$tableCount = [int](& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema LIKE 'shared_%' AND table_type = 'BASE TABLE';")
$roleCount = [int](& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT count(*) FROM pg_roles WHERE rolname IN ('apex_shared_reader','apex_workspace_member') AND NOT rolcanlogin;")
if ($schemaCount -ne 12) { throw "Expected 12 shared schemas; found $schemaCount." }
if ($tableCount -ne 34) { throw "Expected 34 shared base tables; found $tableCount." }
if ($roleCount -ne 2) { throw "Expected two NOLOGIN roles; found $roleCount." }
if ((& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT has_schema_privilege('public', 'public', 'CREATE');").Trim() -ne 'f') {
    throw 'PUBLIC unexpectedly has CREATE permission on the public schema.'
}

& $docker exec $container psql -U $adminUser -d $database -v ON_ERROR_STOP=1 -q -c 'SET client_min_messages TO warning; DROP TABLE IF EXISTS shared_facilities.permission_validation;' | Out-Null
& $docker exec $container psql -U $adminUser -d $database -v ON_ERROR_STOP=1 -c "CREATE TABLE shared_facilities.permission_validation (validation_id integer PRIMARY KEY, validation_text text NOT NULL); INSERT INTO shared_facilities.permission_validation VALUES (1,'reader-select-ok');" | Out-Null
$readerValue = (& $docker exec $container psql -U $adminUser -d $database -Atc "SET ROLE apex_shared_reader; SELECT validation_text FROM shared_facilities.permission_validation WHERE validation_id=1;") -join "`n"
if ($readerValue -notmatch 'reader-select-ok') { throw 'Shared reader could not select shared data.' }

$strictPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $docker exec $container psql -U $adminUser -d $database -c "SET ROLE apex_shared_reader; INSERT INTO shared_facilities.permission_validation VALUES (2,'must-not-write');" 2>$null | Out-Null
$insertExitCode = $LASTEXITCODE
& $docker exec $container psql -U $adminUser -d $database -c 'SET ROLE apex_shared_reader; CREATE TABLE shared_facilities.must_not_create (id integer);' 2>$null | Out-Null
$createExitCode = $LASTEXITCODE
$ErrorActionPreference = $strictPreference
if ($insertExitCode -eq 0) { throw 'Shared reader unexpectedly inserted into shared data.' }
if ($createExitCode -eq 0) { throw 'Shared reader unexpectedly created a shared table.' }

& $docker exec $container psql -U $adminUser -d $database -c 'DROP TABLE shared_facilities.permission_validation;' | Out-Null
Write-Host "PASS: PostgreSQL $serverVersion; PostGIS $postgisVersion; TCP password authentication; 12 schemas; 34 tables; group roles present; shared reader is read-only."
