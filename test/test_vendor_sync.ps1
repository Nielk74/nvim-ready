#Requires -Version 5.1
<#
.SYNOPSIS
    Verify that every plugin declared in lua/plugins/*.lua is also listed
    for vendoring in fetch.ps1.

.DESCRIPTION
    Parses all "owner/repo" lazy.nvim plugin identifiers from lua/plugins/*.lua
    and checks that a matching GitHub URL exists in the $plugins array in
    fetch.ps1.  Fails fast with a clear message when a plugin is added to Lua
    but its fetch.ps1 clone entry is forgotten.

.EXAMPLE
    .\test\test_vendor_sync.ps1
#>

$ErrorActionPreference = "Continue"

$root = Split-Path $PSScriptRoot -Parent

$passCount = 0
$failCount = 0

function Pass([string]$msg) { Write-Host ("  PASS  " + $msg) -ForegroundColor Green;  $script:passCount++ }
function Fail([string]$msg) { Write-Host ("  FAIL  " + $msg) -ForegroundColor Red;    $script:failCount++ }
function Info([string]$msg) { Write-Host ("  info  " + $msg) -ForegroundColor DarkGray }

Write-Host "`n--- Vendor sync check ---" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Extract all "owner/repo" slugs declared in fetch.ps1's $plugins array
# ---------------------------------------------------------------------------
$fetchContent = Get-Content (Join-Path $root "fetch.ps1") -Raw

# Match every GitHub URL inside the $plugins block
$fetchSlugs = [regex]::Matches(
    $fetchContent,
    'https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\.git'
) | ForEach-Object { $_.Groups[1].Value.ToLower() }

Info ("fetch.ps1 declares $($fetchSlugs.Count) plugin URL(s)")

# ---------------------------------------------------------------------------
# 2. Extract lazy.nvim plugin identifiers from lua/plugins/*.lua
#
# Strategy: collect every quoted "owner/repo" string from the lua files, then
# drop false positives.  The only false positives in this codebase are LSP
# method names ("textDocument/hover", "workspace/didChangeConfiguration", ...)
# which always have a camelCase word before the slash ([a-z][A-Z] transition).
# ---------------------------------------------------------------------------
$luaSlugs = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)

$luaDir = Join-Path $root "lua\plugins"
foreach ($f in (Get-ChildItem $luaDir -Filter "*.lua")) {
    $content = Get-Content $f.FullName -Raw
    $matches_ = [regex]::Matches(
        $content,
        '"([A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*)"'
    )
    foreach ($m in $matches_) {
        $slug  = $m.Groups[1].Value
        $owner = $slug.Split('/')[0]
        # Drop LSP/JSON-RPC method namespace prefixes that look like "owner/method"
        # (e.g. "textDocument/hover", "workspace/didChangeConfiguration")
        if ($owner -cin @('textDocument','workspace','window','notebookDocument',
                          'callHierarchy','typeHierarchy','client','telemetry')) { continue }
        $null = $luaSlugs.Add($slug.ToLower())
    }
}

Info ("lua/plugins/ references $($luaSlugs.Count) unique plugin slug(s)")

# ---------------------------------------------------------------------------
# 3. Forward check: every lua plugin must have a fetch.ps1 entry
# ---------------------------------------------------------------------------
$missing = @()
foreach ($slug in ($luaSlugs | Sort-Object)) {
    if ($fetchSlugs -notcontains $slug) { $missing += $slug }
}

if ($missing.Count -eq 0) {
    Pass "All $($luaSlugs.Count) lua plugin(s) are listed in fetch.ps1"
} else {
    foreach ($m in $missing) {
        Fail "Plugin '$m' is in lua/plugins/ but missing from fetch.ps1"
    }
}

# ---------------------------------------------------------------------------
# 4. Reverse info: fetch.ps1 entries with no matching lua spec
#    (not a failure -- these may be transitive deps, utilities, or colorschemes
#    whose name key differs from the GitHub slug)
# ---------------------------------------------------------------------------
$unreferenced = @()
foreach ($slug in $fetchSlugs) {
    if ($luaSlugs -notcontains $slug) { $unreferenced += $slug }
}
if ($unreferenced.Count -gt 0) {
    Info ("$($unreferenced.Count) fetch.ps1 entry(ies) have no direct lua spec " +
          "(transitive deps / colorschemes / utilities -- not an error):")
    foreach ($u in $unreferenced) { Info "  $u" }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- SUMMARY ---" -ForegroundColor Cyan
$col = if ($failCount -eq 0) { "Green" } else { "Red" }
Write-Host ("  " + $passCount + " passed,  " + $failCount + " failed") -ForegroundColor $col
if ($failCount -eq 0) {
    Write-Host "  All tests passed." -ForegroundColor Green
} else {
    Write-Host ("  " + $failCount + " test(s) failed.") -ForegroundColor Red
    exit 1
}
