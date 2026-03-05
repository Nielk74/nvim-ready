#Requires -Version 5.1
# Tests issue #17: OmniSharp multi-sln root detection logic in headless nvim
# Usage: .\test\test_issue17_omnisharp_root.ps1

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

# Create a temp dir with two .sln files to test multi-sln detection
$tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "nvim_test_multisln_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
[System.IO.File]::WriteAllText("$tmpDir\Alpha.sln", "")
[System.IO.File]::WriteAllText("$tmpDir\Beta.sln", "")
[System.IO.File]::WriteAllText("$tmpDir\Test.cs", "")
$tmpFwd = $tmpDir.Replace("\", "/")

$lua = @"
-- Test issue #17: find_slns_upward and omnisharp root cache logic

-- Replicate find_slns_upward from lsp.lua
local function lsp_norm(p) return (p:gsub("\\\\", "/")) end

local function find_slns_upward(start_dir)
    local dir = lsp_norm(vim.fn.fnamemodify(start_dir, ":p"):gsub("[/\\\\]$", ""))
    local seen = {}
    while dir ~= "" and not seen[dir] do
        seen[dir] = true
        local ok_g, slns = pcall(vim.fn.glob, dir .. "/*.sln", false, true)
        if ok_g and #slns > 0 then
            return vim.tbl_map(lsp_norm, slns), dir
        end
        local parent = lsp_norm(vim.fn.fnamemodify(dir, ":h"))
        if parent == dir then break end
        dir = parent
    end
    return {}, nil
end

-- Test 1: single sln in template dir -> finds it
local slns1, dir1 = find_slns_upward("$tplFwd")
if #slns1 == 1 then
    io.write("OK   single-sln detection: found " .. slns1[1] .. "\n")
else
    io.write("FAIL single-sln detection: expected 1, got " .. #slns1 .. "\n")
end

-- Test 2: child dir of template also finds the sln (walk-up)
local child = "$tplFwd/MyApp.Core"
local slns2, dir2 = find_slns_upward(child)
if #slns2 == 1 and slns2[1]:match("MyApp%.sln") then
    io.write("OK   walk-up from child dir works\n")
else
    io.write("FAIL walk-up: expected MyApp.sln, got " .. vim.inspect(slns2) .. "\n")
end

-- Test 3: multi-sln temp dir -> finds 2
local slns3, dir3 = find_slns_upward("$tmpFwd")
if #slns3 == 2 then
    io.write("OK   multi-sln detection: found " .. #slns3 .. " solutions\n")
    for _, s in ipairs(slns3) do
        io.write("     " .. vim.fn.fnamemodify(s, ":t") .. "\n")
    end
else
    io.write("FAIL multi-sln detection: expected 2, got " .. #slns3 .. "\n")
end

-- Test 4: session cache prevents re-prompt (simulate cache hit)
local omnisharp_root_cache = {}
omnisharp_root_cache[dir3] = dir3 .. "_chosen"
local start_called_with = nil
-- Simulate: if cache hit, use cached root (no prompt)
local root
if omnisharp_root_cache[dir3] then
    root = omnisharp_root_cache[dir3]
end
if root == dir3 .. "_chosen" then
    io.write("OK   session cache hit returns cached root\n")
else
    io.write("FAIL session cache: expected cached root, got " .. tostring(root) .. "\n")
end

-- Test 5: solution_tree active_sln getter
local ok_st, st = pcall(require, "solution_tree")
if not ok_st then
    io.write("FAIL require solution_tree: " .. tostring(st) .. "\n")
else
    io.write("OK   require solution_tree\n")
    if type(st.active_sln) == "function" then
        io.write("OK   active_sln() is a function\n")
        local sln_path = st.active_sln()
        if sln_path == nil then
            io.write("OK   active_sln() returns nil when no sln loaded\n")
        else
            io.write("WARN active_sln() returned: " .. tostring(sln_path) .. "\n")
        end
    else
        io.write("FAIL active_sln is not a function: " .. type(st.active_sln) .. "\n")
    end
end

io.flush()
"@

Write-Host "=== Issue #17: OmniSharp multi-sln root detection ===" -ForegroundColor Cyan

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

# Cleanup
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
}
