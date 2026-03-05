#Requires -Version 5.1
# Tests theme.lua persistence: write a known theme, verify require/fields, then
# verify the picker's save() path by mocking vim.ui.select in headless nvim.
# Usage: .\test\test_theme_persist.ps1

$root     = Split-Path $PSScriptRoot -Parent
$initFwd  = ($root + "\init.lua").Replace("\", "/")
$themeLua = Join-Path $root "lua\core\theme.lua"

function Invoke-NvimLua([string]$LuaCode, [int]$TimeoutSec = 30) {
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

Write-Host "=== Theme persistence test ===" -ForegroundColor Cyan

# Back up current theme.lua so we restore it regardless of outcome.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$backup    = [System.IO.File]::ReadAllText($themeLua, $utf8NoBom)

try {

    # -----------------------------------------------------------------------
    # Test 1: written file is valid Lua and contains correct fields
    # Write a known preset (tokyonight-storm) directly from PS, then require
    # it in headless nvim and assert the fields round-tripped correctly.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T1: file round-trip (write from PS, require in nvim) ---" -ForegroundColor DarkCyan

    $knownTheme = @"
-- Theme set by :ThemeSwitch
-- Edit manually for advanced options (see README for full recipes).
return {
    plugin  = "folke/tokyonight.nvim",
    name    = "tokyonight-storm",
    module  = "tokyonight",
    opts    = { style = "storm" },
    lualine = "tokyonight",
}
"@
    [System.IO.File]::WriteAllText($themeLua, $knownTheme, $utf8NoBom)

    $lua1 = @'
local ok, theme = pcall(require, 'core.theme')
if not ok then
  io.write('FAIL require core.theme: ' .. tostring(theme) .. '\n')
  io.flush(); return
end
io.write('OK   core.theme loadable\n')
if theme.name == 'tokyonight-storm' then
  io.write('OK   theme.name = ' .. theme.name .. '\n')
else
  io.write('FAIL theme.name: expected tokyonight-storm, got ' .. tostring(theme.name) .. '\n')
end
if theme.module == 'tokyonight' then
  io.write('OK   theme.module = ' .. theme.module .. '\n')
else
  io.write('FAIL theme.module: expected tokyonight, got ' .. tostring(theme.module) .. '\n')
end
if type(theme.opts) == 'table' and theme.opts.style == 'storm' then
  io.write('OK   theme.opts.style = ' .. theme.opts.style .. '\n')
else
  io.write('FAIL theme.opts.style: expected storm, got ' .. tostring(theme.opts and theme.opts.style) .. '\n')
end
if theme.lualine == 'tokyonight' then
  io.write('OK   theme.lualine = ' .. theme.lualine .. '\n')
else
  io.write('FAIL theme.lualine: expected tokyonight, got ' .. tostring(theme.lualine) .. '\n')
end
io.flush()
'@
    Show-Lines (Invoke-NvimLua -LuaCode $lua1)

    # -----------------------------------------------------------------------
    # Test 2: themepicker.pick() save path
    # Mock vim.ui.select to auto-pick "tokyonight - storm", then call M.pick().
    # After nvim exits, read theme.lua from PS and verify it was rewritten.
    # -----------------------------------------------------------------------
    Write-Host "`n--- T2: picker save path (mock vim.ui.select, verify file rewritten) ---" -ForegroundColor DarkCyan

    # Reset theme.lua to a clearly different state so we can detect the write.
    $resetTheme = @"
-- Theme set by :ThemeSwitch
return {
    plugin  = "folke/tokyonight.nvim",
    name    = "tokyonight-night",
    module  = "tokyonight",
    opts    = { style = "night" },
    lualine = "tokyonight",
}
"@
    [System.IO.File]::WriteAllText($themeLua, $resetTheme, $utf8NoBom)

    # The middle-dot in "tokyonight - storm" label is U+00B7, encoded as UTF-8 C2 B7.
    # In the PS here-string we write it as a plain string; Lua sees the UTF-8 bytes.
    $lua2 = @'
-- Override vim.ui.select to synchronously pick "tokyonight - storm"
local target_label = 'tokyonight \xc2\xb7 storm'

-- Rebuild label with the middle-dot character directly (avoid escape issues).
local dot = '\xc2\xb7'
target_label = 'tokyonight ' .. dot .. ' storm'

local original_select = vim.ui.select
vim.ui.select = function(items, opts, cb)
  for i, item in ipairs(items) do
    if item == target_label then
      cb(item, i)
      return
    end
  end
  -- fallback: pick first item if label not matched
  io.write('WARN target label not found, picking first item: ' .. tostring(items[1]) .. '\n')
  cb(items[1], 1)
end

local ok, M = pcall(require, 'core.themepicker')
if not ok then
  io.write('FAIL require core.themepicker: ' .. tostring(M) .. '\n')
  io.flush(); return
end
io.write('OK   core.themepicker loadable\n')

-- pick() calls apply() then save(); our mocked select is synchronous.
local pick_ok, pick_err = pcall(M.pick)
vim.ui.select = original_select

if not pick_ok then
  io.write('FAIL M.pick() error: ' .. tostring(pick_err) .. '\n')
else
  io.write('OK   M.pick() completed\n')
end
io.flush()
'@
    Show-Lines (Invoke-NvimLua -LuaCode $lua2)

    # Now read the file from PS and check it was overwritten with "storm".
    $written = [System.IO.File]::ReadAllText($themeLua, $utf8NoBom)
    if ($written -match 'storm') {
        Write-Host "OK   theme.lua contains 'storm' after picker save" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "FAIL theme.lua does not contain 'storm' after picker save" -ForegroundColor Red
        Write-Host "     File contents: $written" -ForegroundColor DarkGray
        $fail++
    }
    if ($written -match 'tokyonight') {
        Write-Host "OK   theme.lua plugin field present" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "FAIL theme.lua missing plugin field" -ForegroundColor Red
        $fail++
    }

} finally {
    # Always restore original theme.lua.
    [System.IO.File]::WriteAllText($themeLua, $backup, $utf8NoBom)
    Write-Host "`nINFO theme.lua restored to original" -ForegroundColor DarkGray
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
    exit 1
}
