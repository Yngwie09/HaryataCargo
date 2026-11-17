param([string]$Config='config/local.json')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
if(-not(Test-Path -LiteralPath $Config)){throw 'Isi API_BASE_URL dan key Maps dalam config/local.json terlebih dahulu.'}
node tools/preflight.cjs --android --debug "--config=$Config"
if($LASTEXITCODE -ne 0){throw 'Konfigurasi Android belum lengkap.'}
$settings=Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$env:GOOGLE_MAPS_API_KEY=$settings.GOOGLE_MAPS_ANDROID_API_KEY
$bundledSdk=Join-Path (Split-Path $repo -Parent) '.tools/android-sdk'
if(-not $env:ANDROID_HOME -and (Test-Path -LiteralPath "$bundledSdk/platform-tools")){
    $env:ANDROID_HOME=$bundledSdk
}
if(-not $env:ANDROID_SDK_ROOT -and $env:ANDROID_HOME){$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME}
# Keep the bundled Flutter compiler in one JVM and use the working local TLS route.
$env:JAVA_TOOL_OPTIONS=($env:JAVA_TOOL_OPTIONS+' -Djava.net.preferIPv4Stack=true -Djdk.tls.client.protocols=TLSv1.2 -Dhttps.protocols=TLSv1.2 -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process').Trim()
$flutter=if($env:FLUTTER_ROOT){Join-Path $env:FLUTTER_ROOT 'bin/flutter.bat'}else{Join-Path (Split-Path $repo -Parent) '.tools/flutter/bin/flutter.bat'}
if(-not(Test-Path -LiteralPath $flutter)){$flutter='flutter'}
& $flutter build apk --debug --no-pub --target-platform android-arm64 "--dart-define-from-file=$Config"
if($LASTEXITCODE -ne 0){throw 'Build APK skripsi gagal. Periksa Android SDK dan pesan error di atas.'}
Write-Host 'APK untuk dipasang langsung ke HP: build/app/outputs/flutter-apk/app-debug.apk'
Write-Host 'APK ini menggunakan signing debug; tidak membutuhkan keystore release atau publikasi Play Store.'
