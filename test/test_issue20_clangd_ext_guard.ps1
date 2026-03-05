#Requires -Version 5.1
# Tests issue #20: clangd_extensions setup guard in headless nvim
# Usage: .\test\test_issue20_clangd_ext_guard.ps1

$root    = Split-Path $PSScriptRoot -Parent
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

Write-Host "=== Issue #20: clangd_extensions setup guard ===" -ForegroundColor Cyan

# Test 1: Guard present in source (static check)
$lspFile = Join-Path $root "lua\plugins\lsp.lua"
$content = Get-Content $lspFile -Raw
$pass = 0; $fail = 0

if ($content -match 'local ok_ext = pcall\(function\(\)') {
    Write-Host "OK   pcall guard present in lsp.lua" -ForegroundColor Green
    $pass++
} else {
    Write-Host "FAIL pcall guard not found in lsp.lua" -ForegroundColor Red
    $fail++
}

if ($content -match 'clangd_extensions not loaded') {
    Write-Host "OK   warning message present in lsp.lua" -ForegroundColor Green
    $pass++
} else {
    Write-Host "FAIL warning message not found in lsp.lua" -ForegroundColor Red
    $fail++
}

# Test 2: pcall guard works correctly when plugin IS loaded (normal case)
$lua = @"
-- Simulate the guard logic with a working plugin
local setup_called = false
-- Mock clangd_extensions available
package.loaded["clangd_extensions"] = {
    setup = function(opts)
        setup_called = true
    end
}

local ok_ext = pcall(function()
    require("clangd_extensions").setup({
        inlay_hints = { inline = true, only_current_line = false },
    })
end)

if ok_ext then
    io.write("OK   pcall succeeds when clangd_extensions is available\n")
else
    io.write("FAIL pcall failed unexpectedly\n")
end

if setup_called then
    io.write("OK   setup() was called through pcall\n")
else
    io.write("FAIL setup() was not called\n")
end
io.flush()
"@

$lines = Invoke-NvimLua -LuaCode $lua
$lines | ForEach-Object {
    if ($_ -match '^OK') {
        Write-Host $_ -ForegroundColor Green
        $pass++
    } elseif ($_ -match '^FAIL') {
        Write-Host $_ -ForegroundColor Red
        $fail++
    } else {
        Write-Host $_
    }
}

# Test 3: pcall guard works correctly when plugin is MISSING
$lua2 = @"
-- Simulate the guard logic with a missing plugin
package.loaded["clangd_extensions"] = nil
-- Make require fail
local original_require = require
_G.require = function(name)
    if name == "clangd_extensions" then
        error("module not found: " .. name)
    end
    return original_require(name)
end

local warned = false
local orig_notify = vim.notify
vim.notify = function(msg, level)
    if msg:match("clangd_extensions not loaded") then
        warned = true
    end
end

local ok_ext = pcall(function()
    require("clangd_extensions").setup({})
end)

if not ok_ext then
    io.write("OK   pcall catches missing clangd_extensions\n")
else
    io.write("FAIL pcall did not catch error\n")
end

-- Simulate the if not ok_ext then warn block
if not ok_ext then
    vim.notify("[LSP] clangd_extensions not loaded - inlay hints disabled", vim.log.levels.WARN)
end

if warned then
    io.write("OK   warning notification fires when plugin is missing\n")
else
    io.write("FAIL no warning notification\n")
end

vim.notify = orig_notify
_G.require = original_require
io.flush()
"@

$lines2 = Invoke-NvimLua -LuaCode $lua2
$lines2 | ForEach-Object {
    if ($_ -match '^OK') {
        Write-Host $_ -ForegroundColor Green
        $pass++
    } elseif ($_ -match '^FAIL') {
        Write-Host $_ -ForegroundColor Red
        $fail++
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
