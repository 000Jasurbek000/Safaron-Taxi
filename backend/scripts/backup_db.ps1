param([ValidateSet('daily','weekly')][string]$Kind = 'daily')

$backend = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $backend 'backups'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$file = Join-Path $outDir "$Kind-$stamp.sql"
$env:PGPASSWORD = 'safaron'
docker exec safaron-postgres pg_dump -U safaron safaron | Set-Content -Encoding utf8 $file
if ($LASTEXITCODE -ne 0) {
  Write-Error 'pg_dump amalga oshmadi. Docker konteyner safaron-postgres ishlayotganini tekshiring.'
  exit 1
}
Write-Output "Zaxira: $file"
