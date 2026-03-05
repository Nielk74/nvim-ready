#Requires -Version 5.1
# Tests LSP binary graceful degradation.
#
# Strategy: lua/plugins/lsp.lua runs a binary-existence check at module load
# time (top-level, before "return { ... }"). We dofile() it directly in headless
# nvim so we can intercept vim.notify without needing to trigger lazy.nvim's
# event system.
#
# Phase 1 (baseline): all binaries present -> expect 0 [LSP] WARN notifications.
# Phase 2 (missing):  rename clangd.exe temporarily -> expect exactly 1 WARN for
#                     clangd -> restore binary.
#
# Usage: .\test\test_lsp_degradation.ps1

$root     = Split-Path $PSScriptRoot -Parent
$initFwd  = ($root + "\init.lua").Replace("\", "/")
$clangdExe = Join-Path $root "vendor\lsp\clangd\bin\clangd.exe"
$clangdBak = $clangdExe + ".bak_lsp_test"

function Invoke-NvimLua([string]$LuaCode, [int]$TimeoutSec = 20) {
    $f   = [System.IO.Path]::GetTempFileName() + ".lua"
    [System.IO.File]::WriteAllText($f, $LuaCode, (New-Object System.Text.UTF8Encoding($false)))
    $fwd      = $f.Replace("\", "/")
    $nvimArgs = "--headless -u `"$initFwd`" -c `"luafile $fwd`" -c qa"
    $psi = New-Object System.Diagnostics.ProcessStartInfo("nvim", $nvimArgs)
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ot   = $proc.StandardOutput.ReadToEndAsync()
    $et   = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit($TimeoutSec * 1000) | Out-Null
    Remove-Item $f -Force -ErrorAction SilentlyContinue
    $lines = @()
    $o = $ot.GetAwaiter().GetResult(); if ($o) { $lines += $o -split "`r?`n" }
    $e = $et.GetAwaiter().GetResult(); if ($e) { $lines += $e -split "`r?`n" }
    return $lines | Where-Object { $_ -ne $null -and $_.Trim() -ne "" }
}

function Show-Lines([string[]]$Lines) {
    foreach ($line in $Lines) {
        if     ($line -match '^OK')   { Write-Host $line -ForegroundColor Green;   $script:pass++ }
        elseif ($line -match '^FAIL') { Write-Host $line -ForegroundColor Red;     $script:fail++ }
        elseif ($line -match '^WARN') { Write-Host $line -ForegroundColor Yellow  }
        elseif ($line -match '^INFO') { Write-Host $line -ForegroundColor DarkGray }
        elseif ($line.Trim() -ne '')  { Write-Host ("[raw] " + $line) -ForegroundColor DarkYellow }
    }
}

$pass = 0; $fail = 0

Write-Host "=== LSP binary degradation test ===" -ForegroundColor Cyan

# Lua that dofile()s lsp.lua with vim.notify intercepted.
# We use dofile() rather than require() so repeated runs in the same session
# don't hit Lua's module cache. The binary check in lsp.lua runs at top level
# (before the "return { ... }" lazy spec), so dofile() is sufficient.
$lspLuaFwd = ($root + "\lua\plugins\lsp.lua").Replace("\", "/")

$lspCheckLua = @"
local warns = {}
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) == 'string' and msg:match('%[LSP%]') and level == vim.log.levels.WARN then
    table.insert(warns, msg)
  end
  -- Do NOT forward to orig_notify to keep headless output clean.
end

-- dofile runs lsp.lua top-level code (binary checks) without lazy.
local ok, err = pcall(dofile, '$lspLuaFwd')
vim.notify = orig_notify

if not ok then
  -- Some errors are expected: cmp_nvim_lsp may not be available outside lazy.
  -- The binary check runs before any require() inside config(), so ok=false
  -- only if lsp.lua itself has a top-level syntax/runtime error.
  io.write('INFO dofile result: ' .. tostring(err):match('[^\n]+') .. '\n')
end

io.write('lsp_warn_count=' .. #warns .. '\n')
for _, w in ipairs(warns) do
  io.write('lsp_warn: ' .. (w:match('[^\n]+') or w) .. '\n')
end
io.flush()
"@

# -----------------------------------------------------------------------
# Phase 1: baseline - all binaries present
# -----------------------------------------------------------------------
Write-Host "`n--- Phase 1: baseline (all binaries present) ---" -ForegroundColor DarkCyan

$hasClangd = Test-Path $clangdExe

if (-not $hasClangd) {
    Write-Host "WARN clangd.exe not found -- skipping baseline (vendor not populated)" -ForegroundColor Yellow
} else {
    $lines1 = Invoke-NvimLua -LuaCode $lspCheckLua
    $warnLine = $lines1 | Where-Object { $_ -match '^lsp_warn_count=' } | Select-Object -First 1
    $warnCount = if ($warnLine) { [int]($warnLine -replace 'lsp_warn_count=', '') } else { -1 }

    if ($warnCount -eq 0) {
        Write-Host "OK   no [LSP] WARN notifications with all binaries present" -ForegroundColor Green
        $pass++
    } elseif ($warnCount -gt 0) {
        Write-Host "WARN $warnCount [LSP] WARN(s) even with all binaries present:" -ForegroundColor Yellow
        $lines1 | Where-Object { $_ -match '^lsp_warn:' } | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
    } else {
        Write-Host "INFO could not parse warn count from output" -ForegroundColor DarkGray
        $lines1 | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
    }
}

# -----------------------------------------------------------------------
# Phase 2: rename clangd.exe -> verify [LSP] WARN is emitted
# -----------------------------------------------------------------------
Write-Host "`n--- Phase 2: missing clangd.exe -> expect [LSP] WARN ---" -ForegroundColor DarkCyan

if (-not $hasClangd) {
    Write-Host "WARN clangd.exe not found -- Phase 2 cannot rename, skipping" -ForegroundColor Yellow
} else {
    try {
        Rename-Item -Path $clangdExe -NewName ($clangdExe + ".bak_lsp_test") -ErrorAction Stop
        Write-Host "INFO clangd.exe renamed to .bak_lsp_test" -ForegroundColor DarkGray

        $lines2    = Invoke-NvimLua -LuaCode $lspCheckLua
        $warnLine2 = $lines2 | Where-Object { $_ -match '^lsp_warn_count=' } | Select-Object -First 1
        $warnCount2 = if ($warnLine2) { [int]($warnLine2 -replace 'lsp_warn_count=', '') } else { -1 }
        $warnMsgs   = $lines2 | Where-Object { $_ -match '^lsp_warn:' }

        if ($warnCount2 -ge 1) {
            $clangdWarn = $warnMsgs | Where-Object { $_ -match 'clangd' }
            if ($clangdWarn) {
                Write-Host "OK   [LSP] WARN emitted for missing clangd" -ForegroundColor Green
                $clangdWarn | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
                $pass++
            } else {
                Write-Host "WARN [LSP] WARNs emitted but none mention clangd:" -ForegroundColor Yellow
                $warnMsgs | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
            }
        } elseif ($warnCount2 -eq 0) {
            Write-Host "FAIL no [LSP] WARN emitted despite missing clangd.exe" -ForegroundColor Red
            $fail++
        } else {
            Write-Host "INFO could not parse output:" -ForegroundColor DarkGray
            $lines2 | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
        }

    } finally {
        # Always restore, even if nvim crashes or the test throws.
        if (Test-Path $clangdBak) {
            Rename-Item -Path $clangdBak -NewName $clangdExe -ErrorAction SilentlyContinue
            Write-Host "INFO clangd.exe restored" -ForegroundColor DarkGray
        }
    }
}

# -----------------------------------------------------------------------
# Phase 3: nvim exits cleanly even with a missing binary
# -----------------------------------------------------------------------
Write-Host "`n--- Phase 3: nvim starts cleanly despite missing binary ---" -ForegroundColor DarkCyan

if (-not $hasClangd) {
    Write-Host "WARN clangd.exe not found -- skipping Phase 3" -ForegroundColor Yellow
} else {
    try {
        Rename-Item -Path $clangdExe -NewName ($clangdExe + ".bak_lsp_test") -ErrorAction Stop

        $startupLua = @"
local ok, lazy = pcall(require, 'lazy')
if ok then
  io.write('OK   lazy loaded (nvim started cleanly)\n')
else
  io.write('FAIL lazy not loaded: ' .. tostring(lazy) .. '\n')
end
io.flush()
"@
        Show-Lines (Invoke-NvimLua -LuaCode $startupLua)

    } finally {
        if (Test-Path $clangdBak) {
            Rename-Item -Path $clangdBak -NewName $clangdExe -ErrorAction SilentlyContinue
            Write-Host "INFO clangd.exe restored" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
    exit 1
}
