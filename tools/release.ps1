param(
    [string]$Version,
    [string]$NotesFile,
    [string[]]$AdditionalAsset,
    [switch]$Stable,
    [switch]$Draft,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$modDescPath = Join-Path $repoRoot "mod\modDesc.xml"

if (-not (Test-Path -LiteralPath $modDescPath -PathType Leaf)) {
    throw "modDesc.xml not found: $modDescPath"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    [xml]$modDesc = Get-Content -LiteralPath $modDescPath -Raw
    $Version = $modDesc.modDesc.version
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Version is required and could not be read from modDesc.xml"
}

$tag = "v$Version"
$distRoot = Join-Path $repoRoot "dist"
$assetPath = Join-Path $distRoot "FS25_PhobosRuralLedger_v$Version.zip"
$packageScript = Join-Path $repoRoot "tools\package.ps1"

Push-Location $repoRoot
try {
    $dirty = git status --porcelain --untracked-files=no
    if (-not [string]::IsNullOrWhiteSpace($dirty)) {
        throw "Tracked worktree changes exist. Commit or revert them before releasing."
    }

    git fetch --tags origin

    $localTag = git tag --list $tag
    if (-not [string]::IsNullOrWhiteSpace($localTag)) {
        throw "Tag already exists locally: $tag"
    }

    $remoteTag = git ls-remote --tags origin "refs/tags/$tag"
    if (-not [string]::IsNullOrWhiteSpace($remoteTag)) {
        throw "Tag already exists on origin: $tag"
    }

    $releaseListJson = gh release list --limit 1000 --json tagName
    if ($LASTEXITCODE -ne 0) {
        throw "Could not query GitHub releases."
    }

    $existingRelease = @($releaseListJson | ConvertFrom-Json | Where-Object { $_.tagName -eq $tag })
    if ($existingRelease.Count -gt 0) {
        throw "GitHub release already exists: $tag"
    }

    if ($DryRun) {
        Write-Output "Dry run: would build $assetPath"
        Write-Output "Dry run: would create and push tag $tag"
        Write-Output "Dry run: would create GitHub release $tag"
        return
    }

    & powershell -ExecutionPolicy Bypass -File $packageScript -OutputPath $assetPath

    $commit = git rev-parse --short HEAD
    if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
        $resolvedNotesFile = Resolve-Path -LiteralPath $NotesFile
        $notesArgs = @("--notes-file", $resolvedNotesFile.Path)
    } else {
        $previousTag = git describe --tags --abbrev=0 --match "v*" 2>$null
        if ([string]::IsNullOrWhiteSpace($previousTag)) {
            $changes = git log --pretty=format:"- %s (%h)" -n 20
        } else {
            $changes = git log "$previousTag..HEAD" --pretty=format:"- %s (%h)"
        }

        if ([string]::IsNullOrWhiteSpace($changes)) {
            $changes = "- Packaging-only release."
        }

        $notes = @"
Package: FS25_PhobosRuralLedger_v$Version.zip
Built from commit: $commit

Changes:
$changes
"@
        $notesArgs = @("--notes", $notes)
    }

    git tag -a $tag -m "Phobos' Rural Ledger $tag"
    git push origin $tag

    $releaseAssets = @($assetPath)
    foreach ($assetGroup in $AdditionalAsset) {
        foreach ($asset in ($assetGroup -split ",")) {
            if ([string]::IsNullOrWhiteSpace($asset)) {
                continue
            }
            $resolvedAsset = Resolve-Path -LiteralPath $asset.Trim()
            $releaseAssets += $resolvedAsset.Path
        }
    }

    $releaseArgs = @(
        "release", "create", $tag
    )

    $releaseArgs += $releaseAssets

    $releaseArgs += @(
        "--title", "Phobos' Rural Ledger $tag",
        "--verify-tag"
    )

    if (-not $Stable) {
        $releaseArgs += "--prerelease"
    }

    if ($Draft) {
        $releaseArgs += "--draft"
    }

    $releaseArgs += $notesArgs

    gh @releaseArgs
}
finally {
    Pop-Location
}
