param([string]$Output = 'dist/HaryataCargo-preview.zip')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$web = Join-Path $repo 'build/web'
if (-not (Test-Path -LiteralPath (Join-Path $web 'PREVIEW_ONLY'))) { throw 'Buat build -Preview terlebih dahulu. Paket ini tidak menerima build operasional.' }
$archivePath = [IO.Path]::GetFullPath((Join-Path $repo $Output))
if (-not $archivePath.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output harus berada di repository.' }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archivePath) | Out-Null
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
function Add-ZipFile([string]$Absolute, [string]$EntryName) {
    $entry = $archive.CreateEntry($EntryName, [IO.Compression.CompressionLevel]::Optimal)
    $input = [IO.File]::OpenRead($Absolute)
    $out = $entry.Open()
    try { $input.CopyTo($out) } finally { $input.Dispose(); $out.Dispose() }
}
try {
    Get-ChildItem -LiteralPath $web -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($repo.Length + 1).Replace('\','/')
        Add-ZipFile $_.FullName $relative
    }
    Add-ZipFile (Join-Path $repo 'tools/serve.cjs') 'tools/serve.cjs'
    $entry = $archive.CreateEntry('BACA-DULU.txt')
    $writer = [IO.StreamWriter]::new($entry.Open(), [Text.Encoding]::UTF8)
    try { $writer.Write("HARYATA CARGO - PRATINJAU LOKAL`n`nEkstrak ZIP, buka terminal pada folder hasil ekstraksi, lalu jalankan:`nnode tools/serve.cjs 8085`n`nBuka http://localhost:8085 . Node.js 22 diperlukan. Hentikan dengan Ctrl+C.`n`nIni tampilan baca saja: login, data pengiriman, unggah foto, dan tracking tidak aktif. Tidak perlu Flutter SDK, emulator, database, atau akun Firebase untuk pratinjau ini. Untuk aplikasi operasional gunakan paket source dan panduan koneksi proyek Firebase baru.`n") } finally { $writer.Dispose() }
} finally { $archive.Dispose(); $stream.Dispose() }
Write-Host "Paket pratinjau: $archivePath"
