$ErrorActionPreference = 'Stop'
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$env:PATH = "$(Split-Path $docker);$env:PATH"
$container = 'apex-db'

$health = 'unknown'
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $health = (& $docker inspect $container --format '{{.State.Health.Status}}').Trim()
    if ($health -in @('healthy', 'unhealthy')) { break }
    Start-Sleep -Seconds 2
}
if ($health -ne 'healthy') { throw "Container health is $health." }

$startedBefore = (& $docker inspect $container --format '{{.State.StartedAt}}').Trim()
$restartsBefore = (& $docker inspect $container --format '{{.RestartCount}}').Trim()
Start-Sleep -Seconds 30
$healthAfter = (& $docker inspect $container --format '{{.State.Health.Status}}').Trim()
$startedAfter = (& $docker inspect $container --format '{{.State.StartedAt}}').Trim()
$restartsAfter = (& $docker inspect $container --format '{{.RestartCount}}').Trim()

if ($healthAfter -ne 'healthy') { throw "Container health changed to $healthAfter." }
if ($startedBefore -ne $startedAfter) { throw 'Container start time changed.' }
if ($restartsBefore -ne $restartsAfter) { throw 'Container restart count changed.' }
Write-Host "PASS: continuously healthy for 30 seconds; restart count=$restartsAfter; started=$startedAfter"
