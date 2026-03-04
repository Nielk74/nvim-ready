#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive offline LSP test for custom-nvim.
    Emulates a clean install: only vendor/ + repo + nvim needed.

.DESCRIPTION
    1. Prerequisites  - all vendor binaries present
    2. Startup        - nvim starts without plugin errors
    3. C++ LSP        - clangd attaches on a minimal .cpp file
    4. C# LSP         - OmniSharp attaches on a .cs file in a .sln solution

.EXAMPLE
    cd C:\Users\Antoine\project\custom-nvim
    .\test\run.ps1

    # Skip slow LSP attach tests:
    .\test\run.ps1 -SkipLsp

    # Keep temp dir for inspection after run:
    .\test\run.ps1 -KeepTemp
#>
param(
    [switch]$SkipLsp,
    [switch]$KeepTemp
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$root      = Split-Path $PSScriptRoot -Parent
$testDir   = $PSScriptRoot
$template  = Join-Path $testDir "template"
$init      = Join-Path $root "init.lua"
$lspCheck  = Join-Path $testDir "lsp_check.lua"

$passCount = 0
$failCount = 0
$tmpDir    = $null

function Write-Step([string]$msg) { Write-Host "`n--- $msg ---" -ForegroundColor Cyan }
function Pass([string]$msg)       { Write-Host ("  PASS  " + $msg) -ForegroundColor Green;  $script:passCount++ }
function Fail([string]$msg)       { Write-Host ("  FAIL  " + $msg) -ForegroundColor Red;    $script:failCount++ }
function Info([string]$msg)       { Write-Host ("  info  " + $msg) -ForegroundColor DarkGray }

function Assert-File([string]$label, [string]$path) {
    if (Test-Path $path) { Pass $label }
    else                 { Fail ($label + " missing: " + $path) }
}

# Run nvim headlessly, return combined stdout+stderr lines.
# Uses ProcessStartInfo with a manually-built, properly-quoted arg string
# and async ReadToEnd to avoid stdout/stderr deadlocks.
function Invoke-Nvim([string[]]$NvimArgs, [int]$TimeoutSec = 60) {
    # Build a Windows CommandLineToArgvW-compatible argument string.
    # Elements that contain spaces or double-quotes must be quoted.
    $argStr = ($NvimArgs | ForEach-Object {
        $a = [string]$_
        if ($a -match '[\s"]') {
            $a = $a -replace '(\\+)$', '$1$1'   # double trailing backslashes before closing quote
            $a = $a -replace '"', '\"'            # escape embedded double-quotes
            '"' + $a + '"'
        } else { $a }
    }) -join " "

    $psi                        = New-Object System.Diagnostics.ProcessStartInfo("nvim", $argStr)
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true

    $proc       = [System.Diagnostics.Process]::Start($psi)
    $outTask    = $proc.StandardOutput.ReadToEndAsync()
    $errTask    = $proc.StandardError.ReadToEndAsync()

    $done = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $done) { $proc.Kill() }

    $lines = @()
    if (-not $done) { $lines += "[TIMEOUT] nvim did not exit within ${TimeoutSec}s" }
    $outText = $outTask.GetAwaiter().GetResult()
    $errText = $errTask.GetAwaiter().GetResult()
    if ($outText) { $lines += $outText -split "`r?`n" | Where-Object { $null -ne $_ } }
    if ($errText) { $lines += $errText -split "`r?`n" | Where-Object { $null -ne $_ } }
    return $lines
}

# Print lsp_check.lua output with color. Returns $true if no FAIL lines.
function Show-LspOutput([string[]]$Lines) {
    $clean = $true
    foreach ($line in $Lines) {
        if     ($line -match "^OK   ") { Write-Host ("    " + $line) -ForegroundColor Green    }
        elseif ($line -match "^FAIL ") { Write-Host ("    " + $line) -ForegroundColor Red;     $clean = $false }
        elseif ($line -match "^INFO ") { Write-Host ("    " + $line) -ForegroundColor DarkGray }
        elseif ($line -match "^WARN ") { Write-Host ("    " + $line) -ForegroundColor Yellow   }
        elseif ($line -match "^ERR  ") { Write-Host ("    " + $line) -ForegroundColor Red;     $clean = $false }
        elseif ($line.Trim() -ne "")   { Write-Host ("    [raw] " + $line) -ForegroundColor DarkYellow }
    }
    return $clean
}

# ===========================================================================
# Phase 1 - Prerequisites
# ===========================================================================
Write-Step "Phase 1: Prerequisites"

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $ver = (& nvim --version 2>&1 | Select-Object -First 1)
    Pass ("nvim: " + $ver)
} else {
    Fail "nvim not in PATH"
}

if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $dver = (& dotnet --version 2>&1 | Select-Object -First 1)
    Pass ("dotnet: " + $dver)
} else {
    Fail "dotnet not in PATH (required for OmniSharp)"
}

Assert-File "vendor/lazy.nvim"        (Join-Path $root "vendor\lazy.nvim")
Assert-File "clangd.exe"              (Join-Path $root "vendor\lsp\clangd\bin\clangd.exe")
Assert-File "OmniSharp.dll"           (Join-Path $root "vendor\lsp\omnisharp\OmniSharp.dll")
Assert-File "pyright-langserver.cmd"  (Join-Path $root "vendor\lsp\pyright\node_modules\.bin\pyright-langserver.cmd")
Assert-File "ts-langserver.cmd"       (Join-Path $root "vendor\lsp\ts_ls\node_modules\.bin\typescript-language-server.cmd")

$cpso = Join-Path $root "vendor\parsers\parser\cpp.so"
$cpsd = Join-Path $root "vendor\parsers\parser\cpp.dll"
if ((Test-Path $cpso) -or (Test-Path $cpsd)) { Pass "parser: cpp" }
else { Fail "parser: cpp missing" }

$csso = Join-Path $root "vendor\parsers\parser\c_sharp.so"
$cssd = Join-Path $root "vendor\parsers\parser\c_sharp.dll"
if ((Test-Path $csso) -or (Test-Path $cssd)) { Pass "parser: c_sharp" }
else { Fail "parser: c_sharp missing" }

$prereqFailed = ($script:failCount -gt 0)

# ===========================================================================
# Phase 2 - Clean startup
# ===========================================================================
Write-Step "Phase 2: Clean startup"

# Write Lua to a temp file to avoid Windows command-line quoting issues.
$startupLua = Join-Path $env:TEMP ("nvim_startup_" + $PID + ".lua")
$luaCode = @'
local ok, lazy = pcall(require, 'lazy')
if not ok then
  io.write('plugin_errors=lazy_not_loaded\n')
  io.flush()
  return
end
local errs = {}
for _, p in ipairs(lazy.plugins()) do
  if p._ and p._.error then errs[#errs + 1] = p.name end
end
io.write('plugin_errors=' .. (#errs == 0 and '0' or table.concat(errs, ',')) .. '\n')
io.flush()
'@
[System.IO.File]::WriteAllText($startupLua, $luaCode, (New-Object System.Text.UTF8Encoding($false)))

$startupLuaFwd = $startupLua.Replace("\", "/")
$startupOut = Invoke-Nvim -NvimArgs @("--headless", "-u", $init, "-c", ("luafile " + $startupLuaFwd), "-c", "qa") -TimeoutSec 30
Remove-Item $startupLua -Force -ErrorAction SilentlyContinue

$pLine = $startupOut | Where-Object { $_ -match "^plugin_errors=" } | Select-Object -First 1
if ($pLine -match "plugin_errors=0") {
    Pass "No plugin errors"
} elseif ($pLine) {
    Fail ("Plugin errors: " + ($pLine -replace "plugin_errors=", ""))
} else {
    $rErr = $startupOut | Where-Object { $_ -match "(?i)error" } | Select-Object -First 3
    if ($rErr) {
        Fail "Startup errors (see below)"
        $rErr | ForEach-Object { Info $_ }
    } else {
        Pass "Startup clean (no error output)"
    }
}
$startupOut | Where-Object { $_ -notmatch "^plugin_errors=" -and $_.Trim() -ne "" } |
    Select-Object -First 8 | ForEach-Object { Info $_ }

if ($prereqFailed) {
    Write-Host "`nPrerequisite failures - skipping LSP tests." -ForegroundColor Yellow
    $SkipLsp = $true
}

# ===========================================================================
# Phase 3-5 - LSP tests
# ===========================================================================
if (-not $SkipLsp) {

Write-Step "Phase 3: Preparing test solution"

$tmpDir = Join-Path $env:TEMP ("nvim-lsp-test-" + (Get-Random))
$null   = New-Item -ItemType Directory -Force -Path $tmpDir
Copy-Item -Path "$template\*" -Destination $tmpDir -Recurse -Force
Info ("Temp: " + $tmpDir)

$cppDir = Join-Path $tmpDir "MyApp.NativeLib"
$csDir  = Join-Path $tmpDir "MyApp.Core"

# Write compile_commands.json (no BOM, UTF-8) with absolute forward-slash paths.
$cppFwd  = $cppDir.Replace("\", "/")
$mainFwd = $cppFwd + "/main.cpp"
$cdbJson = "[" + [Environment]::NewLine +
    "  {" + [Environment]::NewLine +
    "    " + [char]34 + "directory" + [char]34 + ": " + [char]34 + $cppFwd + [char]34 + "," + [Environment]::NewLine +
    "    " + [char]34 + "command"   + [char]34 + ": " + [char]34 + "clang++ -std=c++17 -fms-extensions -Wall main.cpp" + [char]34 + "," + [Environment]::NewLine +
    "    " + [char]34 + "file"      + [char]34 + ": " + [char]34 + $mainFwd + [char]34 + [Environment]::NewLine +
    "  }" + [Environment]::NewLine + "]"

[System.IO.File]::WriteAllText(
    (Join-Path $cppDir "compile_commands.json"),
    $cdbJson,
    (New-Object System.Text.UTF8Encoding($false))
)
Pass "compile_commands.json written"

# ---------------------------------------------------------------------------
Write-Step "Phase 4: C++ LSP (clangd)"

$cppFile = Join-Path $cppDir "main.cpp"
Info ("File: " + $cppFile)

$lspCheckFwd = $lspCheck.Replace("\", "/")
$cppOut = Invoke-Nvim -NvimArgs @("--headless", "-u", $init, $cppFile, "-c", ("luafile " + $lspCheckFwd)) -TimeoutSec 70
$null   = Show-LspOutput -Lines $cppOut

$cppOk = ($cppOut | Where-Object { $_ -match "^OK.*LSP attached" })
$cppFx = ($cppOut | Where-Object { $_ -match "^FAIL|TIMEOUT" })
if ($cppOk -and -not $cppFx) { Pass "clangd attached successfully" }
elseif ($cppFx)               { Fail "clangd test failed" }
else                          { Fail "clangd: no attachment reported" }

# ---------------------------------------------------------------------------
Write-Step "Phase 5: C# LSP (OmniSharp)"

$csFile = Join-Path $csDir "Class1.cs"
Info ("File:     " + $csFile)
Info ("Solution: " + (Join-Path $tmpDir "MyApp.sln"))

# OmniSharp JIT + project load is slow - allow 90 s.
$csOut = Invoke-Nvim -NvimArgs @("--headless", "-u", $init, $csFile, "-c", ("luafile " + $lspCheckFwd)) -TimeoutSec 100
$null  = Show-LspOutput -Lines $csOut

$csOk = ($csOut | Where-Object { $_ -match "^OK.*LSP attached" })
$csFx = ($csOut | Where-Object { $_ -match "^FAIL|TIMEOUT" })
if ($csOk -and -not $csFx) { Pass "OmniSharp attached successfully" }
elseif ($csFx)              { Fail "OmniSharp test failed" }
else                        { Fail "OmniSharp: no attachment reported" }

# ---------------------------------------------------------------------------
if ($tmpDir) {
    if ($KeepTemp) {
        Info ("Temp dir kept: " + $tmpDir)
    } else {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        Info "Temp directory removed"
    }
}

} # end -not $SkipLsp

# ===========================================================================
# Summary
# ===========================================================================
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
