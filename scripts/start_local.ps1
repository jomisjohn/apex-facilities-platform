$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
if (-not (Test-Path -LiteralPath $docker)) { throw 'Docker Desktop CLI was not found.' }
$env:PATH = "$(Split-Path $docker);$env:PATH"

& $docker desktop start
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop did not start.' }

Push-Location $repository
try {
    & $docker compose up -d database
    if ($LASTEXITCODE -ne 0) { throw 'The Apex database container did not start.' }
    & (Join-Path $PSScriptRoot 'apply_migrations.ps1')
    & (Join-Path $PSScriptRoot 'validate_database.ps1')
    & (Join-Path $PSScriptRoot 'validate_data.ps1')
} finally {
    Pop-Location
}

Write-Host 'Apex local database is ready at 127.0.0.1:5432.'
