$ErrorActionPreference = 'Stop'

$repository = Split-Path -Parent $PSScriptRoot
$migrationDirectory = Join-Path $repository 'database\migrations'
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"
$container = 'apex-db'
$database = 'apex_facilities'
$adminUser = 'apex_admin'

$databaseReady = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    & $docker exec $container pg_isready -U $adminUser -d $database 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $databaseReady = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $databaseReady) { throw 'The Apex database did not become ready for migrations.' }

& $docker exec $container psql -U $adminUser -d $database -v ON_ERROR_STOP=1 -c @'
CREATE TABLE IF NOT EXISTS public.apex_schema_migrations (
    migration_name text PRIMARY KEY,
    sha256 text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.apex_schema_migrations FROM PUBLIC;
'@ | Out-Null

$migrationFiles = Get-ChildItem -LiteralPath $migrationDirectory -File -Filter '*.sql' | Sort-Object Name
foreach ($migration in $migrationFiles) {
    $checksum = (Get-FileHash -LiteralPath $migration.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $existingOutput = @(& $docker exec $container psql -U $adminUser -d $database -Atc "SELECT sha256 FROM public.apex_schema_migrations WHERE migration_name='$($migration.Name.Replace("'", "''"))';")
    $existing = (($existingOutput | ForEach-Object { "$_" }) -join '').Trim()

    if ($existing) {
        if ($existing -ne $checksum) {
            throw "Applied migration $($migration.Name) has changed. Create a new migration instead of editing history."
        }
        Write-Host "SKIP: $($migration.Name) already applied."
        continue
    }

    $containerFile = "/tmp/$($migration.Name)"
    & $docker cp $migration.FullName "${container}:${containerFile}"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy $($migration.Name) into the database container." }

    try {
        & $docker exec $container psql --quiet -U $adminUser -d $database -v ON_ERROR_STOP=1 -f $containerFile
        if ($LASTEXITCODE -ne 0) { throw "Migration $($migration.Name) failed." }
        & $docker exec $container psql -U $adminUser -d $database -v ON_ERROR_STOP=1 -c "INSERT INTO public.apex_schema_migrations (migration_name, sha256) VALUES ('$($migration.Name.Replace("'", "''"))', '$checksum');" | Out-Null
        Write-Host "APPLIED: $($migration.Name)"
    } finally {
        & $docker exec $container rm -f $containerFile 2>$null | Out-Null
    }
}
