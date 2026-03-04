#Requires -Version 5.1
# Quick parse test for solution_tree.lua
# Usage: .\test\test_sln_parse.ps1

$root = Split-Path $PSScriptRoot -Parent
$tpl  = Join-Path $root "test\template"

function Invoke-NvimLua([string]$LuaCode, [int]$TimeoutSec = 20) {
    $f   = [System.IO.Path]::GetTempFileName() + ".lua"
    [System.IO.File]::WriteAllText($f, $LuaCode, (New-Object System.Text.UTF8Encoding($false)))
    $fwd      = $f.Replace("\", "/")
    $initFwd  = ($root + "\init.lua").Replace("\", "/")
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

$tplFwd = $tpl.Replace("\", "/")

$lua = @"
local st = require('solution_tree')

-- 1. find_slns
local slns, found_dir = (function()
  local dir = '$tplFwd'
  local dir2 = dir:gsub('[/\\\\]+$', '')
  local seen = {}
  while dir2 ~= '' and not seen[dir2] do
    seen[dir2] = true
    local s = vim.fn.glob(dir2 .. '/*.sln', false, true)
    if #s > 0 then return s, dir2 end
    local p = vim.fn.fnamemodify(dir2, ':h')
    if p == dir2 then break end
    dir2 = p
  end
  return {}, nil
end)()

io.write('find_slns: ' .. #slns .. ' found\n')
for _, s in ipairs(slns) do io.write('  sln: ' .. s .. '\n') end

-- 2. detect_and_prompt (internal parse test)
if #slns > 0 then
  local sln_path = slns[1]
  local sln_dir  = vim.fn.fnamemodify(sln_path, ':h')
  local FOLDER   = '2150E333-8FDC-42A3-9474-1A3956D46DE8'
  local projects = {}
  for _, line in ipairs(vim.fn.readfile(sln_path)) do
    local tg, name, rel = line:match('^%s*Project%("{([^}]+)}"%)[^=]*=[^"]*"([^"]+)"[^,]*,[^"]*"([^"]+)"')
    if tg and name then
      if tg:upper() ~= FOLDER then
        local ext = (rel:match('%.([^./\\\\]+)$') or ''):lower()
        local kind = ext == 'csproj' and 'csharp' or (ext == 'vcxproj') and 'cpp' or nil
        if kind then
          table.insert(projects, { name=name, kind=kind, rel=rel })
        end
      end
    end
  end
  io.write('projects: ' .. #projects .. '\n')
  for _, p in ipairs(projects) do
    io.write('  [' .. p.kind .. '] ' .. p.name .. '  (' .. p.rel .. ')\n')
  end

  -- 3. parse csproj
  for _, p in ipairs(projects) do
    local full = (sln_dir .. '/' .. p.rel):gsub('\\', '/')
    io.write('parse ' .. p.kind .. ': ' .. p.name .. '\n')
    local content = vim.fn.readfile(full)
    if content and #content > 0 then
      local sdk = table.concat(content,'\n'):match('<Project%s[^>]*Sdk=')
      io.write('  sdk-style: ' .. (sdk and 'yes' or 'no') .. '\n')
      if p.kind == 'csharp' and sdk then
        local proj_dir = vim.fn.fnamemodify(full, ':h')
        local files = vim.fn.glob(proj_dir .. '/**/*.cs', false, true)
        local filtered = vim.tbl_filter(function(f)
          return not f:match('[/\\\\]obj[/\\\\]') and not f:match('[/\\\\]bin[/\\\\]')
        end, files)
        io.write('  cs files: ' .. #filtered .. '\n')
        for _, f in ipairs(filtered) do
          io.write('    ' .. vim.fn.fnamemodify(f,':t') .. '\n')
        end
      elseif p.kind == 'cpp' then
        local proj_dir = vim.fn.fnamemodify(full, ':h')
        local cnt = table.concat(vim.fn.readfile(full), '\n')
        local files = {}
        for _, tag in ipairs({'ClCompile','ClInclude'}) do
          for inc in cnt:gmatch('<' .. tag .. '%s+Include="([^"]+)"') do
            if not inc:match('%%') then table.insert(files, inc) end
          end
        end
        io.write('  cpp files: ' .. #files .. '\n')
        for _, f in ipairs(files) do io.write('    ' .. f .. '\n') end
      end
    else
      io.write('  ERROR: could not read ' .. full .. '\n')
    end
  end
end
io.flush()
"@

Write-Host "=== Running solution parse test ===" -ForegroundColor Cyan
$lines = Invoke-NvimLua -LuaCode $lua
$lines | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Done." -ForegroundColor Green
