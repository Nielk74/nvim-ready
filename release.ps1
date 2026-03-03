#Requires -Version 5.1
<#
.SYNOPSIS
    Create a GitHub release and upload vendor.zip as an asset.
    Run fetch.ps1 first to produce vendor.zip.

.PARAMETER Tag
    Git tag name for the release (e.g. v1.0, v2025-03).

.PARAMETER Notes
    Release description / changelog text.

.EXAMPLE
    .\release.ps1 -Tag v1.0
    .\release.ps1 -Tag v1.0 -Notes "Updated clangd to 21.1.8, parsers rebuilt."
#>
param(
    [Parameter(Mandatory)][string]$Tag,
    [string]$Notes = "Offline vendor bundle. Extract vendor.zip into the repo root, then run install.ps1."
)

$ErrorActionPreference = "Stop"

$root      = $PSScriptRoot
$vendorZip = Join-Path $root "vendor.zip"

function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "    $msg" -ForegroundColor Green }

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
# Locate gh.exe -- prefer PATH, fall back to the default install location
$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
$ghExe = if ($ghCmd) { $ghCmd.Source } else {
    $candidate = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $candidate) { $candidate } else { $null }
}
if (-not $ghExe) {
    Write-Error "gh CLI not found. Install it from https://cli.github.com then run: gh auth login"
    exit 1
}
Set-Alias gh $ghExe

if (-not (Test-Path $vendorZip)) {
    Write-Error "vendor.zip not found. Run fetch.ps1 first to generate it."
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Tag and push
# ---------------------------------------------------------------------------
Write-Step "Git tag $Tag"

git -C $root tag $Tag -f
git -C $root push origin $Tag --force
Write-Ok "tag pushed"

# ---------------------------------------------------------------------------
# 2. Create release and upload asset
# ---------------------------------------------------------------------------
Write-Step "GitHub release"

$sizeMB = [math]::Round((Get-Item $vendorZip).Length / 1MB, 0)
Write-Host "    Creating release and uploading vendor.zip ($sizeMB MB)..."

gh release create $Tag $vendorZip `
    --title "custom-nvim $Tag" `
    --notes $Notes

Write-Ok "Done"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Release published." -ForegroundColor Green
Write-Host ""
Write-Host "On the offline machine:"
Write-Host "  git clone <repo-url>"
Write-Host "  cd nvim-ready"
Write-Host "  .\install.ps1"
Write-Host ""
Write-Host "install.ps1 will auto-download vendor.zip from the latest release"
Write-Host "if vendor/ is not present locally."
