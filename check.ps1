#Requires -Version 5.1
$c  = $PSScriptRoot
$ok = 0; $miss = 0

function Chk([string]$label, [string]$path) {
    if (Test-Path $path) { Write-Host "OK    $label"; $script:ok++   }
    else                 { Write-Host "MISS  $label"; $script:miss++ }
}

Write-Host "`n=== LAZY PLUGIN ERRORS (headless) ==="
$out = & nvim --headless -u "$c\init.lua" -c "lua local l=require('lazy'); local errs={} for _,p in ipairs(l.plugins()) do if p._.error then errs[#errs+1]=p.name end end; io.write(#errs==0 and 'No plugin errors' or table.concat(errs,', ')); io.write('\n')" -c "qa!" 2>&1
Write-Host $out

Write-Host "`n=== PYTHON PROVIDER ==="
$py = & nvim --headless -u "$c\init.lua" `
    -c "lua io.write('has_python3=' .. vim.fn.has('python3') .. '\n')" `
    -c "lua io.write('python=' .. vim.fn.exepath('python') .. '\n')" `
    -c "qa!" 2>&1
Write-Host $py

Write-Host "`n=== VENDOR DIRS ==="
Chk "vendor/lazy.nvim"     "$c\vendor\lazy.nvim"
Chk "vendor/ripgrep"       "$c\vendor\ripgrep"
Chk "vendor/lazygit"       "$c\vendor\lazygit"
Chk "vendor/lsp/clangd"    "$c\vendor\lsp\clangd\bin"
Chk "vendor/lsp/pyright"   "$c\vendor\lsp\pyright"
Chk "vendor/lsp/omnisharp" "$c\vendor\lsp\omnisharp"
Chk "vendor/lsp/ts_ls"     "$c\vendor\lsp\ts_ls"
Chk "vendor/parsers"       "$c\vendor\parsers\parser"

Write-Host "`n=== BINARIES ==="
Chk "rg.exe"                         "$c\vendor\ripgrep\rg.exe"
Chk "lazygit.exe"                    "$c\vendor\lazygit\lazygit.exe"
Chk "stylua.exe"                     "$c\vendor\formatters\stylua\stylua.exe"
Chk "clangd.exe"                     "$c\vendor\lsp\clangd\bin\clangd.exe"
Chk "pyright-langserver.cmd"         "$c\vendor\lsp\pyright\node_modules\.bin\pyright-langserver.cmd"
Chk "typescript-language-server.cmd" "$c\vendor\lsp\ts_ls\node_modules\.bin\typescript-language-server.cmd"
Chk "OmniSharp.dll"                  "$c\vendor\lsp\omnisharp\OmniSharp.dll"
Chk "prettier.cmd"                   "$c\vendor\lsp\ts_ls\node_modules\.bin\prettier.cmd"

Write-Host "`n=== TREE-SITTER PARSERS ==="
$pd = "$c\vendor\parsers\parser"
foreach ($lang in "lua","vim","vimdoc","query","cpp","c","c_sharp","python","typescript","javascript","tsx","json","yaml","markdown","bash") {
    if ((Test-Path "$pd\$lang.so") -or (Test-Path "$pd\$lang.dll")) {
        Write-Host "OK    parser:$lang"; $ok++
    } else {
        Write-Host "MISS  parser:$lang"; $miss++
    }
}

Write-Host "`n=== VENDORED PLUGINS ==="
$pluginDir = "$c\vendor\plugins"
$luaPluginDir = "$c\lua\plugins"
$missingPlugins = @()

Get-ChildItem "$luaPluginDir\*.lua" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $matches = [regex]::Matches($content, '"([a-zA-Z][a-zA-Z0-9_-]*)/([a-zA-Z0-9_.-]+)"')
    foreach ($m in $matches) {
        $owner = $m.Groups[1].Value
        $pluginName = $m.Groups[2].Value
        if ($owner -notin @("textDocument", "workspace", "window", "client")) {
            if (-not (Test-Path "$pluginDir\$pluginName")) {
                $missingPlugins += "$owner/$pluginName"
            }
        }
    }
}

if ($missingPlugins.Count -eq 0) {
    Write-Host "OK    All referenced plugins vendored"; $ok++
} else {
    Write-Host "MISS  Plugins not vendored: $($missingPlugins -join ', ')"; $miss++
}

Write-Host "`n=== WHEELS ==="
$wd = "$c\vendor\wheels"
Chk "pynvim wheel"  (Get-ChildItem $wd -Filter "pynvim*.whl"  -EA SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)
Chk "black wheel"   (Get-ChildItem $wd -Filter "black*.whl"   -EA SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)
Chk "debugpy wheel" (Get-ChildItem $wd -Filter "debugpy*.whl" -EA SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)

Write-Host "`n=== SUMMARY ==="
Write-Host "$ok OK   /   $miss MISS"
if ($miss -eq 0) { Write-Host "All checks passed." -ForegroundColor Green }
else             { Write-Host "$miss item(s) missing." -ForegroundColor Red }
