#Requires -Version 5.1
# Tests solution_tree.lua module API in headless nvim
# Usage: .\test\test_sln_module.ps1

$root    = Split-Path $PSScriptRoot -Parent
$tplFwd  = (Join-Path $root "test\template").Replace("\", "/")
$initFwd = ($root + "\init.lua").Replace("\", "/")

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

$lua = @"
-- Test solution_tree module API headlessly
local ok, M = pcall(require, 'solution_tree')
if not ok then
  io.write('FAIL require solution_tree: ' .. tostring(M) .. '\n')
  io.flush()
  return
end
io.write('OK   require solution_tree\n')

local sln = '$tplFwd/MyApp.sln'

-- Test detect_and_prompt: override vim.ui.select to auto-pick first option
local original_select = vim.ui.select
vim.ui.select = function(items, opts, cb)
  io.write('OK   vim.ui.select called with ' .. #items .. ' items\n')
  for i, item in ipairs(items) do
    io.write('     ' .. i .. ': ' .. item .. '\n')
  end
  cb(items[1], 1)  -- auto-pick first (solution tree)
end

-- Override vim.cmd split to avoid headless window issues
local cmd_ok = true
local orig_cmd = vim.cmd
vim.cmd = function(s)
  if type(s) == 'string' and (s:match('vsplit') or s:match('wincmd')) then
    -- skip window commands in headless
    return
  end
  local ok2, err = pcall(orig_cmd, s)
  if not ok2 then
    io.write('WARN vim.cmd(' .. tostring(s) .. '): ' .. tostring(err) .. '\n')
  end
end

-- Test open()
local open_ok, open_err = pcall(M.open, sln)
if not open_ok then
  io.write('FAIL M.open: ' .. tostring(open_err) .. '\n')
  io.flush()
  return
end
io.write('OK   M.open succeeded\n')

-- Verify buffer has content
local buf = vim.fn.bufnr('$')
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local line_count = #lines
io.write('INFO buffer lines: ' .. line_count .. '\n')

-- Check for solution header line
if line_count > 0 and lines[1]:match('MyApp%.sln') then
  io.write('OK   header line: ' .. lines[1]:gsub('^%s+','') .. '\n')
else
  io.write('WARN unexpected header: ' .. (lines[1] or 'nil') .. '\n')
end

-- Count project and file entries
local proj_count = 0
local file_count = 0
for _, line in ipairs(lines) do
  if line:match('[csharp]') or line:match('MyApp%.Core') or line:match('MyApp%.NativeLib') then
    proj_count = proj_count + 1
  end
  if line:match('%.cs') or line:match('%.cpp') or line:match('%.h') then
    file_count = file_count + 1
  end
end
io.write('INFO project rows:  ' .. proj_count .. '\n')
io.write('INFO file rows:     ' .. file_count .. '\n')
if proj_count >= 2 then
  io.write('OK   both projects rendered\n')
else
  io.write('FAIL expected >=2 project rows, got ' .. proj_count .. '\n')
end
if file_count >= 3 then
  io.write('OK   files rendered (>= 3: Class1.cs + main.cpp + utils.h)\n')
else
  io.write('FAIL expected >=3 file rows, got ' .. file_count .. '\n')
end

-- Test close (skip if only one window -- headless artifact from skipped vsplit)
if #vim.api.nvim_list_wins() > 1 then
  M.close()
  io.write('OK   M.close succeeded\n')
else
  io.write('OK   M.close skipped (single-window headless)\n')
end

-- Test detect_and_prompt auto-select neo-tree path
vim.ui.select = function(items, opts, cb)
  cb(items[#items], #items)  -- pick last = "File tree"
end
local dp_ok, dp_err = pcall(M.detect_and_prompt, '$tplFwd')
if not dp_ok then
  io.write('FAIL detect_and_prompt: ' .. tostring(dp_err) .. '\n')
else
  io.write('OK   detect_and_prompt (file tree path) succeeded\n')
end

vim.ui.select = original_select
vim.cmd = orig_cmd
io.flush()
"@

Write-Host "=== Solution tree module test ===" -ForegroundColor Cyan
$lines = Invoke-NvimLua -LuaCode $lua
$pass = 0; $fail = 0
$lines | ForEach-Object {
    if ($_ -match '^OK') {
        Write-Host $_ -ForegroundColor Green
        $pass++
    } elseif ($_ -match '^FAIL') {
        Write-Host $_ -ForegroundColor Red
        $fail++
    } elseif ($_ -match '^WARN') {
        Write-Host $_ -ForegroundColor Yellow
    } else {
        Write-Host $_
    }
}
Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
}
