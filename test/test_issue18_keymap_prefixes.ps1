#Requires -Version 5.1
# Tests issue #18: keymap description prefix consistency across plugin files
# Usage: .\test\test_issue18_keymap_prefixes.ps1

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

# Parse plugin files directly for keymap desc= entries (no nvim needed for this check)
Write-Host "=== Issue #18: Keymap description prefix consistency ===" -ForegroundColor Cyan

$pluginDir = Join-Path $root "lua\plugins"
$files = Get-ChildItem $pluginDir -Filter "*.lua"

# Expected prefix conventions per leader group / plugin
$prefixRules = @{
    "telescope" = @("Find:", "Git:")   # find and git ops
    "editor"    = @("Flash:", "Edit:", "Todo:", "Find:", "LSP:", "Session:", "DAP:")
    "git"       = @("Git:")
    "harpoon"   = @("Harpoon:")
    "dap"       = @("DAP:")
    "trouble"   = @("Trouble:")
    "lsp"       = @("LSP:")
    "ui"        = @("Git:", "Explorer:", "Buffer:")
}

$pass = 0
$fail = 0

foreach ($file in $files) {
    $name = $file.BaseName
    if (-not $prefixRules.ContainsKey($name)) { continue }

    $content = Get-Content $file.FullName -Raw
    # Extract all desc = "..." values
    $descs = [regex]::Matches($content, 'desc\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

    $allowed = $prefixRules[$name]
    $bareCount = 0
    $bareExamples = @()

    foreach ($d in $descs) {
        # Skip core editor actions (no prefix needed by convention for core things like "Signature help", "References")
        # Only flag descs that belong to the plugin-specific categories and lack a "Word: " prefix
        $hasPrefix = $d -match '^[A-Z][A-Za-z]+:'
        if (-not $hasPrefix) {
            # Some bare descs are acceptable (e.g. LSP on_attach uses desc = "LSP: " .. desc pattern not captured here)
            # Flag ones that should have a prefix based on their content
            $bareCount++
            if ($bareExamples.Count -lt 3) { $bareExamples += $d }
        }
    }

    if ($bareCount -eq 0) {
        Write-Host "OK   $name.lua : all $($descs.Count) descs have prefixes" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "FAIL $name.lua : $bareCount bare desc(s) found (examples: $($bareExamples -join ', '))" -ForegroundColor Red
        $fail++
    }
}

# Verify specific expected values in key files
$checks = @(
    @{ File = "telescope.lua"; Pattern = 'desc = "Find: files"';          Label = "telescope Find: files" },
    @{ File = "telescope.lua"; Pattern = 'desc = "Git: commits"';          Label = "telescope Git: commits" },
    @{ File = "telescope.lua"; Pattern = 'desc = "Find: in buffer"';       Label = "telescope Find: in buffer" },
    @{ File = "editor.lua";    Pattern = 'desc = "Flash: jump"';           Label = "editor Flash: jump" },
    @{ File = "editor.lua";    Pattern = 'desc = "Edit: undo tree"';       Label = "editor Edit: undo tree" },
    @{ File = "editor.lua";    Pattern = 'desc = "Todo: next"';            Label = "editor Todo: next" },
    @{ File = "editor.lua";    Pattern = 'desc = "Find: TODOs"';           Label = "editor Find: TODOs" },
    @{ File = "ui.lua";        Pattern = 'desc = "Explorer: toggle"';      Label = "ui Explorer: toggle" },
    @{ File = "ui.lua";        Pattern = 'desc = "Buffer: list"';          Label = "ui Buffer: list" }
)

Write-Host ""
Write-Host "--- Specific desc value checks ---"
foreach ($c in $checks) {
    $fpath = Join-Path $pluginDir $c.File
    $content = Get-Content $fpath -Raw
    if ($content -match [regex]::Escape($c.Pattern)) {
        Write-Host "OK   $($c.Label)" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "FAIL $($c.Label) not found in $($c.File)" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "Result: $pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "Result: $pass passed, $fail failed" -ForegroundColor Red
}
