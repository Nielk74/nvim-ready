#Requires -Version 5.1
# Tests solution_tree.lua robustness against bad/missing input files.
#
# Confirmed bugs exercised:
#   - parse_sln() calls vim.fn.readfile() with no fs_stat guard: opening a
#     non-existent .sln path crashes with E484 (Vim error).
#   - parse_csproj() / parse_vcxproj() already have fs_stat guards (no bug there).
#
# Usage: .\test\test_sln_robustness.ps1

$root    = Split-Path $PSScriptRoot -Parent
$initFwd = ($root + "\init.lua").Replace("\", "/")

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
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== Solution tree robustness test ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------
# Helpers: create temp files
# -----------------------------------------------------------------------
$tmpDir = Join-Path $env:TEMP ("nvim-sln-robust-" + $PID)
$null   = New-Item -ItemType Directory -Force -Path $tmpDir

try {

    # -----------------------------------------------------------------------
    # T1: non-existent .sln path
    # parse_sln() calls vim.fn.readfile(path) with no fs_stat guard.
    # Expected (with fix #12): no crash, error surfaced via notify or pcall.
    # Current behaviour (without fix): Vim error E484, unhandled Lua traceback.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T1: M.open() with non-existent .sln path ---" -ForegroundColor DarkCyan

    $missingSlnFwd = ($tmpDir + "\does_not_exist.sln").Replace("\", "/")

    $lua1 = @"
local path = '$missingSlnFwd'
local ok, M = pcall(require, 'solution_tree')
if not ok then
  io.write('FAIL require solution_tree: ' .. tostring(M) .. '\n')
  io.flush(); return
end
-- Suppress window commands (headless)
local orig_cmd = vim.cmd
vim.cmd = function(s)
  if type(s) == 'string' and (s:match('vsplit') or s:match('wincmd')) then return end
  pcall(orig_cmd, s)
end
local open_ok, open_err = pcall(M.open, path)
vim.cmd = orig_cmd
if open_ok then
  -- fix #12: parse_sln now wraps readfile in pcall and returns {} on error
  io.write('OK   M.open() handled missing .sln gracefully (no crash)\n')
elseif tostring(open_err):match('E484') or tostring(open_err):match('readfile') or
       tostring(open_err):match('cannot open') or tostring(open_err):match('No such') then
  io.write('FAIL M.open() raised unhandled E484 on missing .sln (fix #12 not applied)\n')
  io.write('INFO error: ' .. tostring(open_err):match('[^\n]+') .. '\n')
else
  io.write('FAIL M.open() crashed on missing .sln: ' .. tostring(open_err):match('[^\n]+') .. '\n')
end
io.flush()
"@
    Show-Lines (Invoke-NvimLua -LuaCode $lua1)

    # -----------------------------------------------------------------------
    # T2: empty .sln file
    # readfile() returns {} on an empty file, so the parse loop does nothing.
    # Expected: M.open() succeeds, 0 projects, no crash.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T2: M.open() with empty .sln file ---" -ForegroundColor DarkCyan

    $emptySlnPath = Join-Path $tmpDir "empty.sln"
    [System.IO.File]::WriteAllText($emptySlnPath, "", $utf8NoBom)
    $emptySlnFwd  = $emptySlnPath.Replace("\", "/")

    $lua2 = @"
local path = '$emptySlnFwd'
local ok, M = pcall(require, 'solution_tree')
if not ok then
  io.write('FAIL require solution_tree: ' .. tostring(M) .. '\n')
  io.flush(); return
end
local orig_cmd = vim.cmd
vim.cmd = function(s)
  if type(s) == 'string' and (s:match('vsplit') or s:match('wincmd')) then return end
  pcall(orig_cmd, s)
end
local open_ok, open_err = pcall(M.open, path)
vim.cmd = orig_cmd
if open_ok then
  io.write('OK   M.open() did not crash on empty .sln\n')
else
  io.write('FAIL M.open() crashed on empty .sln: ' .. tostring(open_err):match('[^\n]+') .. '\n')
end
io.flush()
"@
    Show-Lines (Invoke-NvimLua -LuaCode $lua2)

    # -----------------------------------------------------------------------
    # T3: .sln with garbage/non-matching content
    # Pattern matching yields zero projects; no file I/O on project files.
    # Expected: M.open() succeeds, no crash.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T3: M.open() with malformed .sln content ---" -ForegroundColor DarkCyan

    $badSlnPath = Join-Path $tmpDir "bad.sln"
    $badContent = "THIS IS NOT A VALID SOLUTION FILE`n<xml>junk</xml>`nrandom text here"
    [System.IO.File]::WriteAllText($badSlnPath, $badContent, $utf8NoBom)
    $badSlnFwd  = $badSlnPath.Replace("\", "/")

    $lua3 = @"
local path = '$badSlnFwd'
local ok, M = pcall(require, 'solution_tree')
if not ok then
  io.write('FAIL require solution_tree: ' .. tostring(M) .. '\n')
  io.flush(); return
end
local orig_cmd = vim.cmd
vim.cmd = function(s)
  if type(s) == 'string' and (s:match('vsplit') or s:match('wincmd')) then return end
  pcall(orig_cmd, s)
end
local open_ok, open_err = pcall(M.open, path)
vim.cmd = orig_cmd
if open_ok then
  io.write('OK   M.open() did not crash on malformed .sln\n')
else
  io.write('FAIL M.open() crashed on malformed .sln: ' .. tostring(open_err):match('[^\n]+') .. '\n')
end
io.flush()
"@
    Show-Lines (Invoke-NvimLua -LuaCode $lua3)

    # -----------------------------------------------------------------------
    # T4: .sln referencing a non-existent .csproj
    # parse_sln() parses the line successfully.
    # parse_csproj() has a fs_stat guard and returns {} for missing files.
    # Expected: M.open() succeeds, project appears in tree but with 0 files.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T4: .sln referencing non-existent .csproj ---" -ForegroundColor DarkCyan

    $orphanSlnPath = Join-Path $tmpDir "orphan.sln"
    $orphanContent = @"
Microsoft Visual Studio Solution File, Format Version 12.00
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "GhostApp", "GhostApp\GhostApp.csproj", "{11111111-1111-1111-1111-111111111111}"
EndProject
Global
EndGlobal
"@
    [System.IO.File]::WriteAllText($orphanSlnPath, $orphanContent, $utf8NoBom)
    $orphanSlnFwd = $orphanSlnPath.Replace("\", "/")

    $lua4 = @"
local path = '$orphanSlnFwd'
local ok, M = pcall(require, 'solution_tree')
if not ok then
  io.write('FAIL require solution_tree: ' .. tostring(M) .. '\n')
  io.flush(); return
end
local orig_cmd = vim.cmd
vim.cmd = function(s)
  if type(s) == 'string' and (s:match('vsplit') or s:match('wincmd')) then return end
  pcall(orig_cmd, s)
end
local open_ok, open_err = pcall(M.open, path)
vim.cmd = orig_cmd
if open_ok then
  io.write('OK   M.open() did not crash on orphan .csproj reference\n')
else
  io.write('FAIL M.open() crashed on orphan .csproj: ' .. tostring(open_err):match('[^\n]+') .. '\n')
end
io.flush()
"@
    Show-Lines (Invoke-NvimLua -LuaCode $lua4)

} finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    # T1 is expected to fail until fix #12 is applied; clarify in output.
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
    exit 1
}
