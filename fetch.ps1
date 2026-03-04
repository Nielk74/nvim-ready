#Requires -Version 5.1
<#
.SYNOPSIS
    Populate vendor/ with every offline dependency.
    Run this ONCE on a machine that has internet access.
    Transfer the whole repository (including vendor/) to the offline target.

.DESCRIPTION
    Downloads and unpacks:
      vendor/lazy.nvim          -- plugin manager
      vendor/plugins/*          -- all neovim plugins
      vendor/lsp/clangd/        -- clangd language server binary
      vendor/lsp/omnisharp/     -- OmniSharp language server (C#)
      vendor/lsp/pyright/       -- pyright language server (Python)
      vendor/lsp/ts_ls/         -- typescript-language-server (TS/JS)
      vendor/parsers/           -- pre-compiled tree-sitter parser DLLs
      vendor/wheels/            -- pynvim + dependencies as pip wheels
      vendor/formatters/        -- stylua binary

    Formatters installed globally via pip / npm (black, prettier) are NOT
    vendored because they depend on the target Python / Node environments.
    Install them separately on the offline machine:
        pip install black --no-index --find-links vendor/wheels/
        npm install -g prettier   (if npm cache is populated)

.REQUIREMENTS
    git, nvim, node, npm, python, pip, curl/Invoke-WebRequest
    For tree-sitter parser compilation: a C compiler on PATH
      (LLVM/clang recommended; run from a Developer PowerShell).
#>

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot

function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "    $msg" -ForegroundColor Green }
function Write-Skip { param([string]$msg) Write-Host "    [skip] $msg" -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
# Helper: clone or update a git repo into a target directory
# ---------------------------------------------------------------------------
function Clone-Or-Update {
    param([string]$url, [string]$dest, [string]$branch = "")
    if (Test-Path (Join-Path $dest ".git")) {
        Write-Skip "$dest already exists - skipping clone"
        return
    }
    $args_ = @("clone", "--depth=1", "--filter=blob:none")
    if ($branch) { $args_ += @("--branch", $branch) }
    $args_ += @($url, $dest)
    git @args_
    Write-Ok "cloned $url"
}

# ---------------------------------------------------------------------------
# Helper: get latest GitHub release download URL matching a pattern
# ---------------------------------------------------------------------------
function Get-GithubRelease {
    param([string]$repo, [string]$pattern)
    $api = "https://api.github.com/repos/$repo/releases/latest"
    $release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "fetch.ps1" }
    $asset = $release.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No asset matching '$pattern' found in $repo latest release ($($release.tag_name))"
    }
    Write-Ok "$repo $($release.tag_name) -> $($asset.name)"
    return $asset.browser_download_url
}

# ---------------------------------------------------------------------------
# 1. lazy.nvim
# ---------------------------------------------------------------------------
Write-Step "lazy.nvim"
Clone-Or-Update "https://github.com/folke/lazy.nvim.git" `
                (Join-Path $root "vendor\lazy.nvim") `
                "stable"

# ---------------------------------------------------------------------------
# 2. Neovim plugins
# ---------------------------------------------------------------------------
Write-Step "Neovim plugins"

$plugins = @(
    # core
    @{ url = "https://github.com/nvim-lua/plenary.nvim.git";                     name = "plenary.nvim"                     },
    # telescope
    @{ url = "https://github.com/nvim-telescope/telescope.nvim.git";             name = "telescope.nvim"                   },
    # treesitter
    @{ url = "https://github.com/nvim-treesitter/nvim-treesitter.git";           name = "nvim-treesitter"                  },
    @{ url = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects.git"; name = "nvim-treesitter-textobjects"    },
    # lsp
    @{ url = "https://github.com/neovim/nvim-lspconfig.git";                     name = "nvim-lspconfig"                   },
    @{ url = "https://github.com/p00f/clangd_extensions.nvim.git";               name = "clangd_extensions.nvim"           },
    # completion
    @{ url = "https://github.com/hrsh7th/nvim-cmp.git";                          name = "nvim-cmp"                         },
    @{ url = "https://github.com/hrsh7th/cmp-nvim-lsp.git";                      name = "cmp-nvim-lsp"                     },
    @{ url = "https://github.com/hrsh7th/cmp-buffer.git";                        name = "cmp-buffer"                       },
    @{ url = "https://github.com/hrsh7th/cmp-path.git";                          name = "cmp-path"                         },
    @{ url = "https://github.com/hrsh7th/cmp-cmdline.git";                       name = "cmp-cmdline"                      },
    @{ url = "https://github.com/hrsh7th/cmp-nvim-lsp-signature-help.git";       name = "cmp-nvim-lsp-signature-help"      },
    @{ url = "https://github.com/L3MON4D3/LuaSnip.git";                          name = "LuaSnip"                          },
    @{ url = "https://github.com/rafamadriz/friendly-snippets.git";              name = "friendly-snippets"                },
    @{ url = "https://github.com/saadparwaiz1/cmp_luasnip.git";                  name = "cmp_luasnip"                      },
    # formatting
    @{ url = "https://github.com/stevearc/conform.nvim.git";                     name = "conform.nvim"                     },
    # navigation
    @{ url = "https://github.com/ThePrimeagen/harpoon.git";                      name = "harpoon";          branch = "harpoon2" },
    # diagnostics / trouble
    @{ url = "https://github.com/folke/trouble.nvim.git";                        name = "trouble.nvim"                         },
    # git
    @{ url = "https://github.com/sindrets/diffview.nvim.git";                    name = "diffview.nvim"                        },
    @{ url = "https://github.com/kdheepak/lazygit.nvim.git";                     name = "lazygit.nvim"                         },
    # dap
    @{ url = "https://github.com/mfussenegger/nvim-dap.git";                     name = "nvim-dap"                             },
    @{ url = "https://github.com/rcarriga/nvim-dap-ui.git";                      name = "nvim-dap-ui"                          },
    @{ url = "https://github.com/nvim-neotest/nvim-nio.git";                     name = "nvim-nio"                             },
    # editor utilities
    @{ url = "https://github.com/folke/todo-comments.nvim.git";                  name = "todo-comments.nvim"                   },
    @{ url = "https://github.com/RRethy/vim-illuminate.git";                     name = "vim-illuminate"                       },
    @{ url = "https://github.com/folke/persistence.nvim.git";                    name = "persistence.nvim"                     },
    # UI
    @{ url = "https://github.com/nvim-tree/nvim-web-devicons.git";                 name = "nvim-web-devicons"                    },
    @{ url = "https://github.com/folke/noice.nvim.git";                          name = "noice.nvim"                           },
    # UI - colorschemes (all vendored so theme can be changed offline)
    @{ url = "https://github.com/folke/tokyonight.nvim.git";                     name = "tokyonight.nvim"                  },
    @{ url = "https://github.com/catppuccin/nvim.git";                            name = "catppuccin"                       },
    @{ url = "https://github.com/rebelot/kanagawa.nvim.git";                     name = "kanagawa.nvim"                    },
    @{ url = "https://github.com/rose-pine/neovim.git";                          name = "rose-pine"                        },
    @{ url = "https://github.com/EdenEast/nightfox.nvim.git";                    name = "nightfox.nvim"                    },
    @{ url = "https://github.com/ellisonleao/gruvbox.nvim.git";                  name = "gruvbox.nvim"                     },
    @{ url = "https://github.com/navarasu/onedark.nvim.git";                     name = "onedark.nvim"                     },
    @{ url = "https://github.com/nvim-lualine/lualine.nvim.git";                 name = "lualine.nvim"                     },
    @{ url = "https://github.com/nvim-neo-tree/neo-tree.nvim.git";               name = "neo-tree.nvim";   branch = "v3.x" },
    @{ url = "https://github.com/MunifTanjim/nui.nvim.git";                      name = "nui.nvim"                         },
    @{ url = "https://github.com/lewis6991/gitsigns.nvim.git";                   name = "gitsigns.nvim"                    },
    @{ url = "https://github.com/lukas-reineke/indent-blankline.nvim.git";       name = "indent-blankline.nvim"            },
    @{ url = "https://github.com/folke/which-key.nvim.git";                      name = "which-key.nvim"                   },
    @{ url = "https://github.com/rcarriga/nvim-notify.git";                      name = "nvim-notify"                      },
    # editor
    @{ url = "https://github.com/windwp/nvim-autopairs.git";                     name = "nvim-autopairs"                   },
    @{ url = "https://github.com/numToStr/Comment.nvim.git";                     name = "Comment.nvim"                     },
    @{ url = "https://github.com/JoosepAlviste/nvim-ts-context-commentstring.git"; name = "nvim-ts-context-commentstring"  },
    @{ url = "https://github.com/kylechui/nvim-surround.git";                    name = "nvim-surround"                    },
    @{ url = "https://github.com/tpope/vim-repeat.git";                          name = "vim-repeat"                       },
    @{ url = "https://github.com/folke/flash.nvim.git";                          name = "flash.nvim"                       },
    @{ url = "https://github.com/NvChad/nvim-colorizer.lua.git";                 name = "nvim-colorizer.lua"               },
    @{ url = "https://github.com/mbbill/undotree.git";                           name = "undotree"                         },
    @{ url = "https://github.com/j-hui/fidget.nvim.git";                         name = "fidget.nvim"                      }
)

$pluginDir = Join-Path $root "vendor\plugins"
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null

foreach ($p in $plugins) {
    $dest   = Join-Path $pluginDir $p.name
    $branch = if ($p.ContainsKey('branch')) { $p.branch } else { "" }
    Clone-Or-Update $p.url $dest $branch
}

# ---------------------------------------------------------------------------
# 3. LSP binaries
# ---------------------------------------------------------------------------
Write-Step "LSP binaries"

$lspDir = Join-Path $root "vendor\lsp"
New-Item -ItemType Directory -Force -Path $lspDir | Out-Null

# -- clangd (standalone binary from clangd releases) -------------------------
$clangdDir = Join-Path $lspDir "clangd"
if (-not (Test-Path (Join-Path $clangdDir "bin\clangd.exe"))) {
    $url = Get-GithubRelease "clangd/clangd" "clangd-windows-*.zip"
    $zip = Join-Path $env:TEMP "clangd.zip"
    Write-Host "    Downloading clangd..."
    Invoke-WebRequest -Uri $url -OutFile $zip
    $tmp = Join-Path $env:TEMP "clangd_extract"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $tmp
    # The zip has a single top-level folder; move its contents to clangdDir
    $inner = Get-ChildItem $tmp | Select-Object -First 1
    if ($inner) {
        New-Item -ItemType Directory -Force -Path $clangdDir | Out-Null
        Get-ChildItem $inner.FullName | Copy-Item -Destination $clangdDir -Recurse -Force
    }
    Remove-Item $tmp -Recurse -Force
    Remove-Item $zip -Force
    Write-Ok "clangd extracted to $clangdDir"
} else {
    Write-Skip "clangd already present"
}

# -- omnisharp (OmniSharp-Roslyn .NET) ---------------------------------------
$omnisharpDir = Join-Path $lspDir "omnisharp"
if (-not (Test-Path (Join-Path $omnisharpDir "OmniSharp.dll"))) {
    # Use the net6.0 package which runs on any .NET 6+ runtime
    $url = Get-GithubRelease "OmniSharp/omnisharp-roslyn" "omnisharp-win-x64-net6.0.zip"
    $zip = Join-Path $env:TEMP "omnisharp.zip"
    Write-Host "    Downloading omnisharp..."
    Invoke-WebRequest -Uri $url -OutFile $zip
    New-Item -ItemType Directory -Force -Path $omnisharpDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $omnisharpDir -Force
    Remove-Item $zip -Force
    Write-Ok "omnisharp extracted to $omnisharpDir"
} else {
    Write-Skip "omnisharp already present"
}

# -- pyright (npm package, installed locally) --------------------------------
$pyrightDir = Join-Path $lspDir "pyright"
$pyrightBin = Join-Path $pyrightDir "node_modules\.bin\pyright-langserver.cmd"
if (-not (Test-Path $pyrightBin)) {
    Write-Host "    Installing pyright via npm..."
    New-Item -ItemType Directory -Force -Path $pyrightDir | Out-Null
    npm install --prefix $pyrightDir pyright
    Write-Ok "pyright installed at $pyrightDir"
} else {
    Write-Skip "pyright already present"
}

# -- typescript-language-server (npm package, installed locally) -------------
$tsLsDir = Join-Path $lspDir "ts_ls"
$tsLsBin = Join-Path $tsLsDir "node_modules\.bin\typescript-language-server.cmd"
if (-not (Test-Path $tsLsBin)) {
    Write-Host "    Installing typescript-language-server via npm..."
    New-Item -ItemType Directory -Force -Path $tsLsDir | Out-Null
    npm install --prefix $tsLsDir typescript-language-server typescript prettier
    Write-Ok "ts_ls installed at $tsLsDir"
} else {
    Write-Skip "ts_ls already present"
}

# Install prettier separately if it was missed (e.g. ts_ls was already present)
$prettierBin = Join-Path $tsLsDir "node_modules\.bin\prettier.cmd"
if (-not (Test-Path $prettierBin)) {
    Write-Host "    Installing prettier into ts_ls node_modules..."
    npm install --prefix $tsLsDir prettier
    Write-Ok "prettier installed at $tsLsDir"
} else {
    Write-Skip "prettier already present"
}

# ---------------------------------------------------------------------------
# 4. Tree-sitter parsers (compiled on this machine, reused offline)
# ---------------------------------------------------------------------------
Write-Step "Tree-sitter parsers"

$parsersDir = Join-Path $root "vendor\parsers"
New-Item -ItemType Directory -Force -Path $parsersDir | Out-Null

$parserSrc = Join-Path $parsersDir "parser"

# Check if parsers are already built.
# The new nvim-treesitter installs parsers as <lang>.so even on Windows.
$neededParsers = @(
    "lua","vim","vimdoc","query",
    "cpp","c","c_sharp","python",
    "typescript","javascript","tsx","jsdoc",
    "json","yaml","toml","ini",
    "html","css","markdown","markdown_inline","bash"
)
$existing = if (Test-Path $parserSrc) {
    @(Get-ChildItem $parserSrc -Filter "*.so" -ErrorAction SilentlyContinue).BaseName
} else { @() }

$missing = @($neededParsers | Where-Object { $_ -notin $existing })
if ($missing.Count -eq 0) {
    Write-Skip "All parsers already compiled"
} else {
    Write-Host "    Parsers to build: $($missing -join ', ')"

    # -- Download tree-sitter CLI binary -----------------------------------------
    # The new nvim-treesitter (0.10+) compiles grammar sources by calling
    # 'tree-sitter build', not gcc/clang directly. We vendor the CLI so fetch.ps1
    # does not require it to be pre-installed.
    # tree-sitter CLI is a build-time tool only -- keep it in TEMP, not vendor/.
    $tsCliDir = Join-Path $env:TEMP "tree-sitter-cli"
    New-Item -ItemType Directory -Force -Path $tsCliDir | Out-Null
    $tsCliExe = Join-Path $tsCliDir "tree-sitter.exe"
    if (-not (Test-Path $tsCliExe)) {
        Write-Host "    Downloading tree-sitter CLI (build-time only, not vendored)..."
        $tsGzUrl  = Get-GithubRelease "tree-sitter/tree-sitter" "tree-sitter-windows-x64.gz"
        $tsGzPath = Join-Path $env:TEMP "tree-sitter-windows-x64.gz"
        Invoke-WebRequest -Uri $tsGzUrl -OutFile $tsGzPath
        Add-Type -AssemblyName System.IO.Compression
        $gzIn  = [System.IO.File]::OpenRead($tsGzPath)
        $gz    = [System.IO.Compression.GzipStream]::new($gzIn, [System.IO.Compression.CompressionMode]::Decompress)
        $fsOut = [System.IO.File]::Create($tsCliExe)
        $gz.CopyTo($fsOut)
        $fsOut.Close(); $gz.Close(); $gzIn.Close()
        Remove-Item $tsGzPath -Force
        Write-Ok "tree-sitter CLI -> $tsCliExe"
    } else {
        Write-Skip "tree-sitter CLI already in TEMP"
    }

    # -- Activate MSVC build environment -----------------------------------------
    # tree-sitter build uses whatever C compiler is on PATH. On Windows, MSVC
    # (cl.exe) works, but it requires vcvars64.bat to set INCLUDE/LIB/PATH.
    # Running fetch.ps1 from "Developer PowerShell for VS 2022" pre-activates this.
    # If not already activated, we attempt to source vcvars64.bat automatically.
    $savedPath = $env:PATH
    $env:PATH  = $tsCliDir + ";" + $env:PATH

    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        $vcvars = Get-ChildItem `
            "C:\Program Files\Microsoft Visual Studio" `
            -Recurse -Filter "vcvars64.bat" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($vcvars) {
            Write-Host "    Activating MSVC environment ($($vcvars.FullName))..."
            $tmpBat = Join-Path $env:TEMP "ts_vcvars.bat"
            # Redirect stderr inside the batch (2>nul) so vcvars internal warnings
            # (e.g. vswhere.exe not found) never reach PowerShell's error stream.
            "@echo off`r`ncall `"$($vcvars.FullName)`" 2>nul`r`nset" |
                Set-Content $tmpBat -Encoding ASCII
            $envLines = cmd /c $tmpBat
            Remove-Item $tmpBat -Force
            foreach ($line in $envLines) {
                if ($line -match '^([^=]+)=(.*)$') {
                    [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
                }
            }
            $env:PATH = $tsCliDir + ";" + $env:PATH
            Write-Ok "MSVC environment activated"
        } else {
            Write-Warning "cl.exe not found and vcvars64.bat not located."
            Write-Warning "Re-run from 'Developer PowerShell for VS 2022' if compilation fails."
        }
    } else {
        Write-Ok "cl.exe already on PATH"
    }

    # -- Write headless Neovim init that compiles parsers ------------------------
    # New nvim-treesitter API (0.10+):
    #   - No TSInstallSync command; no 'nvim-treesitter.configs' module.
    #   - require('nvim-treesitter').install(langs) returns an async Task.
    #   - Call :wait(timeout_ms) on the Task to block until complete.
    $rootFwd       = $root       -replace '\\', '/'
    $parsersDirFwd = $parsersDir -replace '\\', '/'
    $parserList    = ($missing | ForEach-Object { "'$_'" }) -join ", "
    $tmpInit       = Join-Path $env:TEMP "ts_fetch_init.lua"

    $luaLines = @(
        "vim.opt.rtp:prepend('$rootFwd/vendor/plugins/nvim-treesitter')",
        "require('nvim-treesitter.config').setup({ install_dir = '$parsersDirFwd' })",
        "local task = require('nvim-treesitter').install({ $parserList })",
        "task:wait(1800000)",
        "vim.cmd('quit!')"
    )
    # Set-Content -Encoding UTF8 adds a BOM in PS 5.1; Lua rejects BOM.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($tmpInit, $luaLines, $utf8NoBom)

    Write-Host "    Running nvim headless to compile parsers (may take several minutes)..."
    # Run without 2>&1: nvim warnings go to the terminal directly, avoiding
    # PowerShell treating stderr output as error records under Stop mode.
    & nvim --headless -u $tmpInit

    # Restore PATH (MSVC env vars changed for this process only - no system effect)
    $env:PATH = $savedPath

    Write-Ok "Parsers compiled to $parserSrc"
}

# ---------------------------------------------------------------------------
# 5. Python wheels (pynvim + deps)
# ---------------------------------------------------------------------------
Write-Step "Python wheels"

$wheelsDir = Join-Path $root "vendor\wheels"
New-Item -ItemType Directory -Force -Path $wheelsDir | Out-Null

$existingWheels = @(Get-ChildItem $wheelsDir -Filter "pynvim*.whl" -ErrorAction SilentlyContinue)
if ($existingWheels.Count -gt 0) {
    Write-Skip "pynvim wheel already downloaded"
} else {
    pip download pynvim --dest $wheelsDir --quiet
    Write-Ok "pynvim + dependencies saved to $wheelsDir"
}

# Also download black for Python formatting
$existingBlack = @(Get-ChildItem $wheelsDir -Filter "black*.whl" -ErrorAction SilentlyContinue)
if ($existingBlack.Count -gt 0) {
    Write-Skip "black wheel already downloaded"
} else {
    pip download black --dest $wheelsDir --quiet
    Write-Ok "black + dependencies saved to $wheelsDir"
}

# ---------------------------------------------------------------------------
# 6. stylua formatter binary
# ---------------------------------------------------------------------------
Write-Step "stylua"

$stulaDir  = Join-Path $root "vendor\formatters\stylua"
$stulaExe  = Join-Path $stulaDir "stylua.exe"
if (-not (Test-Path $stulaExe)) {
    $url = Get-GithubRelease "JohnnyMorganz/StyLua" "stylua-windows-x86_64.zip"
    $zip = Join-Path $env:TEMP "stylua.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip
    New-Item -ItemType Directory -Force -Path $stulaDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $stulaDir -Force
    Remove-Item $zip -Force
    Write-Ok "stylua extracted to $stulaDir"
} else {
    Write-Skip "stylua already present"
}

# ---------------------------------------------------------------------------
# 7. ripgrep binary (required by Telescope find_files and live_grep)
# ---------------------------------------------------------------------------
Write-Step "ripgrep"

$rgDir = Join-Path $root "vendor\ripgrep"
$rgExe = Join-Path $rgDir "rg.exe"
if (-not (Test-Path $rgExe)) {
    $url = Get-GithubRelease "BurntSushi/ripgrep" "ripgrep-*-x86_64-pc-windows-msvc.zip"
    $zip = Join-Path $env:TEMP "ripgrep.zip"
    Write-Host "    Downloading ripgrep..."
    Invoke-WebRequest -Uri $url -OutFile $zip
    $tmp = Join-Path $env:TEMP "rg_extract"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $tmp
    # Zip has a single versioned subdirectory; move its contents up
    $inner = Get-ChildItem $tmp | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $rgDir | Out-Null
    Get-ChildItem $inner.FullName | Copy-Item -Destination $rgDir -Recurse -Force
    Remove-Item $tmp -Recurse -Force
    Remove-Item $zip -Force
    Write-Ok "ripgrep extracted to $rgDir"
} else {
    Write-Skip "ripgrep already present"
}

# ---------------------------------------------------------------------------
# 8. lazygit binary (used by lazygit.nvim)
# ---------------------------------------------------------------------------
Write-Step "lazygit"

$lazygitDir = Join-Path $root "vendor\lazygit"
$lazygitExe = Join-Path $lazygitDir "lazygit.exe"
if (-not (Test-Path $lazygitExe)) {
    $url = Get-GithubRelease "jesseduffield/lazygit" "lazygit_*_Windows_x86_64.zip"
    $zip = Join-Path $env:TEMP "lazygit.zip"
    Write-Host "    Downloading lazygit..."
    Invoke-WebRequest -Uri $url -OutFile $zip
    New-Item -ItemType Directory -Force -Path $lazygitDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $lazygitDir -Force
    Remove-Item $zip -Force
    Write-Ok "lazygit extracted to $lazygitDir"
} else {
    Write-Skip "lazygit already present"
}

# Also download debugpy wheel for Python DAP support
Write-Step "debugpy wheel"

$existingDebugpy = @(Get-ChildItem $wheelsDir -Filter "debugpy*.whl" -ErrorAction SilentlyContinue)
if ($existingDebugpy.Count -gt 0) {
    Write-Skip "debugpy wheel already downloaded"
} else {
    pip download debugpy --dest $wheelsDir --quiet
    Write-Ok "debugpy saved to $wheelsDir"
}

# ---------------------------------------------------------------------------
# 8. Package vendor.zip (GitHub release asset)
# ---------------------------------------------------------------------------
Write-Step "Package vendor.zip"

$vendorZip = Join-Path $root "vendor.zip"
if (Test-Path $vendorZip) { Remove-Item $vendorZip -Force }
Write-Host "    Compressing vendor/ -> vendor.zip (may take a moment)..."
Compress-Archive -Path (Join-Path $root "vendor") -DestinationPath $vendorZip
$sizeMB = [math]::Round((Get-Item $vendorZip).Length / 1MB, 0)
Write-Ok "vendor.zip ($sizeMB MB) created"
Write-Host "    Run release.ps1 to publish it as a GitHub release asset."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "vendor/ is ready." -ForegroundColor Green
Write-Host ""
Write-Host "Option A - transfer by file (USB / network share):"
Write-Host "  Copy this entire repository (including vendor/) to the offline machine"
Write-Host "  then run install.ps1 there."
Write-Host ""
Write-Host "Option B - transfer via GitHub release:"
Write-Host "  `$env:GITHUB_TOKEN = 'ghp_...'"
Write-Host "  .\release.ps1 -Tag v1.0"
Write-Host "  On the offline machine: git clone + .\install.ps1 (auto-downloads vendor.zip)"
Write-Host ""
Write-Host "Offline machine still needs (system-wide):"
Write-Host "  - Neovim 0.10+, Git, Node.js, Python 3, .NET SDK"
Write-Host "  - Visual Studio 2022 with C++ (for MSVC headers + compiler)"
Write-Host ""
Write-Host "Formatters installed from vendor/wheels/ on offline machine:"
Write-Host "  pip install black --no-index --find-links vendor\wheels\"
Write-Host '  prettier is bundled inside vendor/lsp/ts_ls/node_modules/.bin/'
