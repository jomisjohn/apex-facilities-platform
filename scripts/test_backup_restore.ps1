$ErrorActionPreference = 'Stop'
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"
$container = 'apex-db'
$database = 'apex_facilities'
$adminUser = 'apex_admin'
$restoreDatabase = 'apex_validation_restore'
$dumpFile = '/tmp/apex_validation.dump'

try {
    & $docker exec $container dropdb -U $adminUser --if-exists $restoreDatabase | Out-Null
    & $docker exec $container rm -f $dumpFile | Out-Null
    & $docker exec $container pg_dump -U $adminUser -d $database -Fc -f $dumpFile
    if ($LASTEXITCODE -ne 0) { throw 'Backup creation failed.' }
    & $docker exec $container createdb -U $adminUser -T template0 $restoreDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Restore database creation failed.' }
    & $docker exec $container pg_restore -U $adminUser -d $restoreDatabase --exit-on-error $dumpFile
    if ($LASTEXITCODE -ne 0) { throw 'Backup restoration failed.' }
    $schemaCount = [int](& $docker exec $container psql -U $adminUser -d $restoreDatabase -Atc "SELECT count(*) FROM information_schema.schemata WHERE schema_name LIKE 'shared_%';")
    if ($schemaCount -ne 12) { throw "Restored database contains $schemaCount shared schemas." }
    Write-Host 'PASS: custom-format backup restored successfully with all 12 shared schemas.'
} finally {
    & $docker exec $container rm -f $dumpFile 2>$null | Out-Null
    & $docker exec $container dropdb -U $adminUser --if-exists $restoreDatabase 2>$null | Out-Null
}
