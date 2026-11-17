param([string]$Config = 'config/local.json', [int]$Port = 8085, [switch]$Preview, [switch]$ServeOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
if ($ServeOnly) { node tools/serve.cjs $Port; exit $LASTEXITCODE }
$flutter = if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT 'bin/flutter.bat' } else { Join-Path (Split-Path $repo -Parent) '.tools/flutter/bin/flutter.bat' }
if (-not (Test-Path -LiteralPath $flutter)) { $flutter = 'flutter' }
if ($Preview) {
    & $flutter build web --release --no-pub --optimization-level=2 --no-wasm-dry-run --no-web-resources-cdn --dart-define=PREVIEW_MODE=true
} else {
    if (-not (Test-Path -LiteralPath $Config)) { throw 'Isi config/local.json. Untuk pratinjau tanpa server gunakan tools/local.ps1 -Preview.' }
    $settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
    node tools/preflight.cjs "--config=$Config"
    if ($LASTEXITCODE -ne 0) { throw 'Konfigurasi proyek baru belum lengkap.' }
    & $flutter build web --release --no-pub --optimization-level=2 --no-wasm-dry-run --no-web-resources-cdn "--dart-define-from-file=$Config"
}
if ($LASTEXITCODE -ne 0) { throw 'Build web gagal. Perbaiki error di atas.' }
$htmlPath = Join-Path $repo 'build/web/index.html'
$html = [IO.File]::ReadAllText($htmlPath)
if ($Preview) {
    $html = $html.Replace('<script src="maps-loader.js" data-api-key="__GOOGLE_MAPS_WEB_API_KEY__" defer></script>', '')
    [IO.File]::WriteAllText((Join-Path $repo 'build/web/PREVIEW_ONLY'), 'Read-only preview; not a production artifact.')
} else {
    $key = [System.Net.WebUtility]::HtmlEncode($settings.GOOGLE_MAPS_WEB_API_KEY)
    $html = $html.Replace('__GOOGLE_MAPS_WEB_API_KEY__', $key)
    $previewMarker = Join-Path $repo 'build/web/PREVIEW_ONLY'
    if (Test-Path -LiteralPath $previewMarker) { Remove-Item -LiteralPath $previewMarker }
}
[IO.File]::WriteAllText($htmlPath, $html)
Write-Host "Dashboard: http://localhost:$Port — hentikan dengan Ctrl+C"
node tools/serve.cjs $Port
