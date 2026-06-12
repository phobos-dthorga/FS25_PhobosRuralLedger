param(
    [string]$SourcePath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = "mod"
}

if ([System.IO.Path]::IsPathRooted($SourcePath)) {
    $modRoot = $SourcePath
} else {
    $modRoot = Join-Path $repoRoot $SourcePath
}

if (-not (Test-Path -LiteralPath $modRoot -PathType Container)) {
    throw "Mod source folder not found: $modRoot"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $distRoot = Join-Path $repoRoot "dist"
    if ($SourcePath -eq "mod") {
        $packageName = "FS25_PhobosRuralLedger"
    } else {
        $packageName = Split-Path -Leaf $modRoot
    }
    $OutputPath = Join-Path $distRoot "$packageName.zip"
}

$resolvedOutputParent = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($resolvedOutputParent)) {
    $resolvedOutputParent = Get-Location
}

New-Item -ItemType Directory -Force -Path $resolvedOutputParent | Out-Null

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$modRootPath = (Resolve-Path -LiteralPath $modRoot).Path.TrimEnd("\", "/")
$modRootPrefix = $modRootPath + [System.IO.Path]::DirectorySeparatorChar
$archive = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    Get-ChildItem -LiteralPath $modRootPath -Recurse -File -Force | ForEach-Object {
        $relativePath = $_.FullName.Substring($modRootPrefix.Length)
        $entryName = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, "/")
        $entryName = $entryName.Replace([System.IO.Path]::AltDirectorySeparatorChar, "/")

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $_.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

Write-Output "Created $OutputPath"
