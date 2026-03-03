#Requires -Version 5.1
<#
.SYNOPSIS
    Offline installer. Run this on the target (air-gapped) machine.
    vendor/ must already be populated - run fetch.ps1 on a machine with
    internet access first, then transfer the whole directory here.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root       = $PSScriptRoot
$nvimConfig = Join-Path $env:LOCALAPPDATA "nvim"
$vendorDir  = Join-Path $root "vendor"

Write-Host ""
Write-Host "custom-nvim offline install"
Write-Host "---------------------------"
Write-Host "Source : $root"
Write-Host "Target : $nvimConfig"
Write-Host ""

# ---------------------------------------------------------------------------
# Guard: vendor/ must exist -- try to download from latest GitHub release
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $vendorDir "lazy.nvim"))) {
    $vendorZip = Join-Path $root "vendor.zip"

    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    $ghExe = if ($ghCmd) { $ghCmd.Source } else {
        $c = "C:\Program Files\GitHub CLI\gh.exe"; if (Test-Path $c) { $c } else { $null }
    }
    if ($ghExe) {
        Write-Host "vendor/ not found. Downloading vendor.zip from latest GitHub release..."
        & $ghExe release download --pattern "vendor.zip" --dir $root --clobber
    } elseif (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        Write-Host "vendor/ not found. Fetching latest release info..."
        $api  = "https://api.github.com/repos/Nielk74/nvim-ready/releases/latest"
        $info = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "install.ps1" }
        $url  = ($info.assets | Where-Object { $_.name -eq "vendor.zip" } |
                 Select-Object -First 1).browser_download_url
        if ($url) {
            Write-Host "Downloading $url ..."
            curl.exe -L -o $vendorZip $url
        }
    }

    if (Test-Path $vendorZip) {
        Write-Host "Extracting vendor.zip..."
        Expand-Archive -Path $vendorZip -DestinationPath $root -Force
        Remove-Item $vendorZip -Force
        Write-Host "vendor/ extracted."
    }

    if (-not (Test-Path (Join-Path $vendorDir "lazy.nvim"))) {
        Write-Error @"
vendor\lazy.nvim not found and could not be downloaded.
Either run fetch.ps1 on a machine with internet access and copy vendor/ here,
or run release.ps1 to publish a GitHub release and re-run install.ps1.
"@
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 1. Backup existing config
# ---------------------------------------------------------------------------
if (Test-Path $nvimConfig) {
    $item = Get-Item $nvimConfig
    if ($item.LinkType -eq "Junction") {
        [System.IO.Directory]::Delete($nvimConfig, $false)
        Write-Host "Removed existing junction."
    } else {
        $backup = "${nvimConfig}.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item -Path $nvimConfig -Destination $backup
        Write-Host "Existing config backed up to $backup"
    }
}

# ---------------------------------------------------------------------------
# 2. Create directory junction
# ---------------------------------------------------------------------------
Write-Host "Creating junction: $nvimConfig -> $root"
try {
    New-Item -ItemType Junction -Path $nvimConfig -Target $root | Out-Null
    Write-Host "Junction created."
} catch {
    Write-Warning "PowerShell junction failed: $_"
    Write-Host "Trying cmd mklink /J ..."
    $result = & cmd.exe /c "mklink /J `"$nvimConfig`" `"$root`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "mklink failed: $result`nTry running as Administrator or enable Developer Mode."
        exit 1
    }
    Write-Host $result
}

# ---------------------------------------------------------------------------
# 3. Install pynvim from local wheels (no internet)
# ---------------------------------------------------------------------------
Write-Host ""
$wheelsDir = Join-Path $root "vendor\wheels"
$pip = Get-Command pip -ErrorAction SilentlyContinue
if ($null -eq $pip) {
    Write-Warning "pip not found - skipping pynvim. Install Python and re-run."
} elseif (-not (Test-Path $wheelsDir)) {
    Write-Warning "vendor\wheels\ not found - skipping pynvim. Run fetch.ps1 first."
} else {
    Write-Host "Installing pynvim from local wheels (no network)..."
    pip install pynvim --no-index --find-links $wheelsDir --quiet
    Write-Host "pynvim installed."
}

# ---------------------------------------------------------------------------
# 4. Add formatter and LSP binaries to user PATH (this session + permanent)
# ---------------------------------------------------------------------------
$pathAdditions = @(
    (Join-Path $root "vendor\formatters\stylua"),
    (Join-Path $root "vendor\lsp\clangd\bin")
)

$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
foreach ($p in $pathAdditions) {
    if (Test-Path $p) {
        if ($userPath -notlike "*$p*") {
            $userPath = "$p;$userPath"
            [System.Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
            $env:PATH = "$p;$env:PATH"
            Write-Host "Added to PATH: $p"
        } else {
            Write-Host "[skip] Already in PATH: $p"
        }
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Installation complete." -ForegroundColor Green
Write-Host ""
Write-Host "Launch Neovim: nvim"
Write-Host "All plugins load from vendor/. No network access is used."
Write-Host ""
Write-Host "Optional - install formatters from local wheels:"
Write-Host "  pip install black --no-index --find-links vendor\wheels\"
Write-Host ""
Write-Host "Verify setup inside Neovim:"
Write-Host "  :Lazy        -- all plugins should show as 'loaded' (no install needed)"
Write-Host "  :LspInfo     -- shows attached language servers per buffer"
Write-Host "  :checkhealth -- overall status"
