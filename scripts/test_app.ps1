$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$python = Join-Path $repoRoot '.venv\Scripts\python.exe'

if (-not (Test-Path $python)) {
    throw 'Create the repository virtual environment first: py -3.12 -m venv .venv'
}

Push-Location $repoRoot
try {
    & $python -m ruff check apps tests
    if ($LASTEXITCODE -ne 0) { throw 'Ruff validation failed.' }

    & $python -m pytest -m 'not database' -q
    if ($LASTEXITCODE -ne 0) { throw 'Local application tests failed.' }

    if ($env:APEX_TEST_DATABASE_URL) {
        & $python -m pytest -m database -q
        if ($LASTEXITCODE -ne 0) { throw 'Database application tests failed.' }
    }
    else {
        Write-Host 'SKIP: database integration requires APEX_TEST_DATABASE_URL for a non-admin student login.'
    }
}
finally {
    Pop-Location
}
