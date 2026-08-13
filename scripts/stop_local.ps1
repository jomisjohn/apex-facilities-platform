$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"

Push-Location $repository
try {
    & $docker compose stop database
    if ($LASTEXITCODE -ne 0) { throw 'The Apex database container did not stop cleanly.' }
} finally {
    Pop-Location
}

Write-Host 'Apex local database is stopped. Docker Desktop remains available for other projects.'
