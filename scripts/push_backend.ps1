# Backend ni GitHub'ga yuklash
# Ishga tushirish: .\scripts\push_backend.ps1
$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

git add backend
git commit -m "Update backend"
git push origin main
