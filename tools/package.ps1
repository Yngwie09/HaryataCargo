param([string]$Output = 'dist/HaryataCargo-source.zip')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$archivePath = [IO.Path]::GetFullPath((Join-Path $repo $Output))
if (-not $archivePath.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output harus berada dalam folder repository.' }
$parent = Split-Path -Parent $archivePath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $paths = git ls-files --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) { throw 'Tidak dapat membaca daftar file repository.' }
    foreach ($relative in ($paths | Sort-Object -Unique)) {
        if ($relative -match '^(dist|build|\.git|\.tools)/' -or $relative -match '(^|/)(node_modules|build|\.gradle|\.dart_tool)/' -or $relative -match '(local\.json|google-services\.json|key\.properties|\.jks|\.keystore|service-account\.json|\.private\.(json|txt))$' -or ($relative -match '(^|/)\.env($|\.)' -and $relative -notmatch '(^|/)\.env\.example$') -or $relative -match '^config/migration-export/') { continue }
        $absolute = [IO.Path]::GetFullPath((Join-Path $repo $relative))
        if (-not $absolute.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path di luar repository.' }
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { continue }
        $entry = $archive.CreateEntry($relative.Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
        $input = [IO.File]::OpenRead($absolute)
        $entryStream = $entry.Open()
        try { $input.CopyTo($entryStream) } finally { $input.Dispose(); $entryStream.Dispose() }
    }
} finally { $archive.Dispose(); $stream.Dispose() }
Write-Host "Paket source: $archivePath"
