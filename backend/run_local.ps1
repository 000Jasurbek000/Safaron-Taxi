# SAFARON — lokal backend (Windows)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "========================================"
Write-Host " SAFARON lokal test"
Write-Host "========================================"

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
  Write-Host "[1] virtualenv yaratilmoqda..."
  python -m venv .venv
} else {
  Write-Host "[1] virtualenv bor"
}

$py = ".\.venv\Scripts\python.exe"

if (-not (Test-Path ".\.env")) {
  Copy-Item ".\.env.example" ".\.env"
  Write-Host "[2] .env .env.example dan nusxa qilindi"
} else {
  Write-Host "[2] .env saqlanadi"
}

New-Item -ItemType Directory -Force -Path data, uploads\drivers, uploads\vehicles, uploads\docs | Out-Null

Write-Host "[3] dependencylar..."
& $py -m pip install -q -r requirements.txt

Write-Host "[4] import test..."
& $py -c "from app.main import app; print(app.title)"
if ($LASTEXITCODE -ne 0) { throw "app import xato" }

Write-Host "========================================"
Write-Host " SUCCESS — http://127.0.0.1:8000"
Write-Host " Admin:   http://127.0.0.1:8000/admin/"
Write-Host " Docs:    http://127.0.0.1:8000/docs"
Write-Host " Health:  http://127.0.0.1:8000/health"
Write-Host "========================================"

& $py -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
