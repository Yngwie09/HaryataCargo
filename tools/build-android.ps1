param([string]$Config = 'config/local.json')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
if (-not (Test-Path -LiteralPath $Config)) { throw 'Konfigurasi proyek baru belum tersedia: config/local.json' }
$settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
node tools/preflight.cjs --android "--config=$Config"
if ($LASTEXITCODE -ne 0) { throw 'Konfigurasi Android belum lengkap.' }
if (-not $settings.GOOGLE_MAPS_ANDROID_API_KEY -or $settings.GOOGLE_MAPS_ANDROID_API_KEY -match 'YOUR') { throw 'Isi GOOGLE_MAPS_ANDROID_API_KEY.' }
$env:GOOGLE_MAPS_API_KEY = $settings.GOOGLE_MAPS_ANDROID_API_KEY
$flutter = if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT 'bin/flutter.bat' } else { Join-Path (Split-Path $repo -Parent) '.tools/flutter/bin/flutter.bat' }
if (-not (Test-Path -LiteralPath $flutter)) { $flutter = 'flutter' }
& $flutter build apk --release --no-pub --target-platform android-arm64 "--dart-define-from-file=$Config"
if ($LASTEXITCODE -ne 0) { throw 'Build Android gagal. Periksa SDK Android, alamat API, Maps, dan signing.' }
Write-Host 'APK: build/app/outputs/flutter-apk/app-release.apk'
