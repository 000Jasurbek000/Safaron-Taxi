# SAFARON APK ni build qilib serverga joylash
$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

Write-Host "Flutter APK yig'ilmoqda..."
flutter build apk --release

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dstRoot = "SAFARON.apk"
$dstRelease = "backend\releases\SAFARON.apk"

Copy-Item $src $dstRoot -Force
New-Item -ItemType Directory -Force -Path "backend\releases" | Out-Null
Copy-Item $src $dstRelease -Force

# pubspec versiyasini version.json ga yozish
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $ver = $Matches[1]
    $build = [int]$Matches[2]
    $json = @{ version = $ver; build = $build; filename = "SAFARON.apk" } | ConvertTo-Json
    Set-Content "backend\releases\version.json" $json -Encoding UTF8
    Write-Host "Versiya: $ver (build $build)"
}

Write-Host "Tayyor:"
Write-Host "  $dstRoot"
Write-Host "  $dstRelease"
Write-Host "Telefondan: Profil -> Ilovani yangilash"
