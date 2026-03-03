# custom-nvim

A Neovim configuration for C++ (MSVC), C#, Python, TypeScript, and JavaScript
development on Windows — designed for fully offline use after a one-time fetch.

Requires Neovim 0.10+. Tested on 0.11.0.

---

## How it works

The repository contains only Lua configuration. All external dependencies
(plugins, LSP binaries, tree-sitter parsers, pip wheels) live in `vendor/`,
which is excluded from git. You populate `vendor/` once on a machine that has
internet access, then transfer the whole directory to any air-gapped machine.
After that, nothing ever touches the network.

```
custom-nvim/
  init.lua                  boot lazy.nvim from vendor/lazy.nvim
  install.ps1               run on the offline target machine
  fetch.ps1                 run ONCE on an internet-connected machine
  lua/
    core/                   options, keymaps, autocmds
    plugins/                one file per feature group
  vendor/                   .gitignore'd — populated by fetch.ps1
    lazy.nvim/
    plugins/                all neovim plugins as shallow git clones
    lsp/
      clangd/               standalone clangd binary
      omnisharp/            OmniSharp-Roslyn .dll
      pyright/              pyright via npm (local node_modules)
      ts_ls/                typescript-language-server via npm
    parsers/                pre-compiled tree-sitter .dll files
    formatters/
      stylua/               stylua.exe
    wheels/                 pynvim + black as pip wheels
```

---

## Prerequisites

These must be present on both the fetch machine and the offline target.

| Tool | Used for |
|------|----------|
| Neovim 0.10+ | obviously |
| Git | cloning plugins in fetch.ps1; Neovim uses it for gitsigns |
| Node.js 18+ | pyright, ts_ls npm install in fetch.ps1; runtime for both LSPs |
| Python 3.8+ | pynvim provider; black formatter; pyright LSP |
| .NET SDK 6+ | running OmniSharp (C# LSP) |
| Visual Studio 2022 with C++ | MSVC compiler and headers for C/C++ development |

Needed only on the **fetch machine**:

| Tool | Used for |
|------|----------|
| npm | installing pyright and ts_ls |
| pip | downloading pynvim and black as wheels |
| A C compiler on PATH | compiling tree-sitter parsers (use Developer PowerShell or install LLVM) |

---

## Setup

### Step 1 — fetch (internet machine)

```powershell
git clone <this-repo> custom-nvim
cd custom-nvim

# Run from a Developer PowerShell so cl.exe is on PATH for parser compilation.
# A regular PowerShell works too but tree-sitter parsers may fail to compile.
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # once, if not already set
.\fetch.ps1
```

`fetch.ps1` will:
- Clone lazy.nvim and all 31 plugins into `vendor/plugins/`
- Download the latest clangd release binary into `vendor/lsp/clangd/`
- Download the latest OmniSharp-Roslyn release into `vendor/lsp/omnisharp/`
- Install pyright and typescript-language-server via npm into `vendor/lsp/`
- Compile tree-sitter parsers and copy the `.dll` files to `vendor/parsers/`
- Download pynvim and black as pip wheels into `vendor/wheels/`
- Download the latest stylua release binary into `vendor/formatters/`

Running fetch.ps1 a second time is safe — already-present items are skipped.

### Step 2 — transfer

Copy the entire directory (including `vendor/`) to the offline machine. A USB
drive, a network share that is accessible only for the copy, or any other
method works. The directory is typically 500 MB–1 GB depending on plugin sizes.

### Step 3 — install (offline machine)

```powershell
cd custom-nvim
.\install.ps1
```

`install.ps1` will:
- Back up any existing `%LOCALAPPDATA%\nvim`
- Create a directory junction: `%LOCALAPPDATA%\nvim` -> this directory
- Install pynvim from `vendor/wheels/` with pip (`--no-index`, no network)
- Add `vendor/formatters/stylua/` and `vendor/lsp/clangd/bin/` to the user PATH

### Step 4 — verify

```
nvim
:Lazy          -- all plugins should show as loaded, no install button
:LspInfo       -- lists attached servers for the current filetype
:checkhealth   -- overall health, including Python provider
```

---

## Plugin list

| Category | Plugins |
|----------|---------|
| Plugin manager | lazy.nvim |
| Colorscheme | tokyonight.nvim (night) |
| Statusline | lualine.nvim |
| File explorer | neo-tree.nvim |
| Fuzzy finder | telescope.nvim + plenary.nvim |
| Syntax / folds | nvim-treesitter + treesitter-textobjects |
| LSP client | nvim-lspconfig |
| Completion | nvim-cmp + 5 sources |
| Snippets | LuaSnip + friendly-snippets |
| Formatting | conform.nvim |
| Git decorations | gitsigns.nvim |
| Indent guides | indent-blankline.nvim |
| Auto-pairs | nvim-autopairs |
| Commenting | Comment.nvim |
| Surround | nvim-surround |
| Navigation | flash.nvim |
| Key hints | which-key.nvim |
| Notifications | nvim-notify |
| LSP progress | fidget.nvim |
| Color preview | nvim-colorizer.lua |
| Undo tree | undotree |

---

## Keybindings

`<leader>` is Space.

### General

| Key | Action |
|-----|--------|
| `<leader>w` | Save |
| `<leader>q` | Quit |
| `<leader>Q` | Quit all |
| `jk` | Exit insert mode |
| `<Esc>` | Clear search highlight |
| `<leader>u` | Toggle undo tree |

### Windows and buffers

| Key | Action |
|-----|--------|
| `Ctrl+h/j/k/l` | Move between windows |
| `Ctrl+Arrow` | Resize window |
| `Shift+h / Shift+l` | Previous / next buffer |
| `<leader>bd` | Delete buffer |
| `<leader>sv` | Vertical split |
| `<leader>sh` | Horizontal split |

### File explorer (neo-tree)

| Key | Action |
|-----|--------|
| `<leader>e` | Toggle neo-tree |
| `<leader>E` | Reveal current file |
| `<leader>be` | Buffer list float |

### Telescope

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Open buffers |
| `<leader>fr` | Recent files |
| `<leader>fh` | Help tags |
| `<leader>fs` | Document symbols |
| `<leader>fS` | Workspace symbols |
| `<leader>fd` | Diagnostics |
| `<leader>fk` | Keymaps |
| `<leader>/` | Fuzzy in current buffer |

Inside Telescope: `Ctrl+j/k` to move, `Ctrl+q` to quickfix, `Esc` to close.

### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | References |
| `gi` | Implementation |
| `gt` | Type definition |
| `K` | Hover docs |
| `Ctrl+s` | Signature help (normal + insert) |
| `<leader>rn` | Rename |
| `<leader>ca` | Code action |
| `<leader>lf` | Format (LSP) |
| `<leader>lF` | Format (conform) |
| `<leader>li` | LSP info |
| `<leader>lr` | Restart LSP |
| `[d / ]d` | Prev / next diagnostic |
| `<leader>de` | Diagnostic float |
| `<leader>dq` | Diagnostic quickfix list |

### Git (gitsigns)

| Key | Action |
|-----|--------|
| `]h / [h` | Next / previous hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>gc/gb/gs` | Telescope git views |

### Treesitter text objects

| Key | Action |
|-----|--------|
| `af / if` | Around / inside function |
| `ac / ic` | Around / inside class |
| `aa / ia` | Around / inside argument |
| `]f / [f` | Jump to next / prev function |
| `Ctrl+Space` | Expand node selection |
| `Backspace` | Shrink node selection |

---

## Language-specific notes

### C / C++ (MSVC)

clangd reads `compile_commands.json` from the project root. Generate it:

```powershell
# CMake project
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
Copy-Item build\compile_commands.json .

# MSBuild / Visual Studio project (install compiledb first)
pip install compiledb
compiledb msbuild MyProject.sln
```

For MSVC header resolution, launch Neovim from a Developer PowerShell so
`cl.exe` is on the PATH. You can also configure headers explicitly via a
`.clangd` file in the project root:

```yaml
# .clangd
CompileFlags:
  Compiler: cl
  Add:
    - /std:c++20
    - --target=x86_64-pc-windows-msvc
```

clang-format is bundled in `vendor/lsp/clangd/bin/` alongside clangd and is
added to PATH by install.ps1.

### C#

omnisharp-roslyn runs via `dotnet vendor/lsp/omnisharp/OmniSharp.dll`. It
indexes the solution automatically when you open a `.cs` file. If there are
multiple `.sln` files, it may prompt for selection.

csharpier is not vendored. Install it once on the offline machine:

```powershell
dotnet tool install -g csharpier
```

This uses the .NET tool cache, which can be pre-populated on an internet
machine with `dotnet tool install -g csharpier --tool-path vendor\dotnet-tools`
and then copied across.

### Python

pyright picks up virtual environments automatically when `.venv/` or
`pyrightconfig.json` is present. Configure the interpreter explicitly:

```json
// pyrightconfig.json
{
  "pythonPath": ".venv/Scripts/python.exe",
  "typeCheckingMode": "standard"
}
```

black is available offline:

```powershell
pip install black --no-index --find-links vendor\wheels\
```

### TypeScript / JavaScript

ts_ls attaches to any project with `tsconfig.json` or `jsconfig.json`.

prettier is bundled inside `vendor/lsp/ts_ls/node_modules/.bin/` and is
referenced directly by conform.nvim — no global npm install needed.

---

## Formatters summary

| Formatter | Language | Status after install.ps1 |
|-----------|----------|--------------------------|
| clang-format | C / C++ | ready (in PATH via vendor/) |
| stylua | Lua | ready (in PATH via vendor/) |
| prettier | TS/JS/JSON/HTML/CSS | ready (bundled in ts_ls node_modules) |
| black | Python | run `pip install black --no-index --find-links vendor\wheels\` |
| csharpier | C# | run `dotnet tool install -g csharpier` |

---

## Updating

On a machine with internet access, run `fetch.ps1` again. It will pull the
latest commits for every plugin and re-download LSP binaries only if they are
missing (delete the target directory first to force a re-download). Then
transfer the updated `vendor/` to offline machines.

---

## Troubleshooting

**Lazy shows an error about vendor/lazy.nvim not found**
`vendor/` is not present. Run `fetch.ps1` on an internet machine and copy the
result to this machine.

**A plugin is listed as `not loaded` in :Lazy**
The plugin's directory under `vendor/plugins/` is missing. Check the name
matches the last segment of the GitHub path (e.g. `plenary.nvim`, not
`nvim-lua`). Re-run `fetch.ps1`.

**LSP does not attach**
Run `:LspInfo`. The binary path is printed on startup as a warning if it does
not exist. Verify the file is present at `vendor/lsp/<name>/...`. Paths are
defined at the top of `lua/plugins/lsp.lua`.

**Tree-sitter highlights are missing**
The parser for that language may not be compiled. On the fetch machine, open
Neovim and run `:TSInstallSync! <language>` with `parser_install_dir` pointing
to `vendor/parsers/`, then copy the new `.dll` to the offline machine.

**clangd does not find MSVC headers**
Launch Neovim from a Developer PowerShell (search "Developer PowerShell for
VS 2022" in the Start menu). Alternatively, use a `.clangd` file to pass
explicit include paths.

**pynvim install fails offline**
Ensure `vendor/wheels/` contains `pynvim`, `msgpack`, and `greenlet` wheels.
If they are missing, re-run `fetch.ps1` on the internet machine.
