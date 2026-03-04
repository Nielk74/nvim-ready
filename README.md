# custom-nvim

A Neovim configuration for C++ (MSVC), C#, Python, TypeScript, and JavaScript
development on Windows — designed for fully offline use after a one-time fetch.

Requires Neovim 0.10+. Tested on 0.11.0.

---

## How it works

The repository contains only Lua configuration. All external dependencies
(plugins, LSP binaries, tree-sitter parsers, pip wheels, standalone binaries)
live in `vendor/`, which is excluded from git. You populate `vendor/` once on a
machine that has internet access, then transfer the whole directory to any
air-gapped machine. After that, nothing ever touches the network.

```
custom-nvim/
  init.lua                  boot lazy.nvim from vendor/lazy.nvim
  install.ps1               run on the offline target machine
  fetch.ps1                 run ONCE on an internet-connected machine
  check.ps1                 verify the install (34 checks)
  lua/
    core/                   options, keymaps, autocmds, theme.lua, themepicker.lua
    plugins/                one file per feature group
    solution_tree.lua       VS Solution Explorer-style sidebar
  test/
    run.ps1                 headless LSP integration test suite
    lsp_check.lua           Lua harness for LSP attach/diagnostic checks
    test_sln_parse.ps1      headless solution parsing logic tests
    test_sln_module.ps1     headless solution_tree module API tests
    template/               minimal VS2022 solution (C# + C++ projects)
  vendor/                   .gitignore'd — populated by fetch.ps1
    lazy.nvim/
    plugins/                all neovim plugins as shallow git clones
    lsp/
      clangd/               standalone clangd binary + clang-format
      omnisharp/            OmniSharp-Roslyn .dll
      pyright/              pyright via npm (local node_modules)
      ts_ls/                typescript-language-server + prettier via npm
    parsers/                pre-compiled tree-sitter parser files
    formatters/
      stylua/               stylua.exe
    ripgrep/                rg.exe (required by Telescope)
    lazygit/                lazygit.exe (used by lazygit.nvim)
    wheels/                 pynvim + black + debugpy as pip wheels
    dap/                    optional — place codelldb here for C/C++ debugging
```

---

## Prerequisites

These must be present on both the fetch machine and the offline target.

| Tool | Used for |
|------|----------|
| Neovim 0.10+ | obviously |
| Git | cloning plugins in fetch.ps1; used by gitsigns, diffview, lazygit |
| Node.js 18+ | pyright and ts_ls npm install; runtime for both LSPs |
| Python 3.8+ | pynvim provider; black formatter; pyright LSP; debugpy (DAP) |
| .NET SDK 6+ | running OmniSharp (C# LSP) |
| Visual Studio 2022 with C++ | MSVC compiler and headers for C/C++ development |

Needed only on the **fetch machine**:

| Tool | Used for |
|------|----------|
| npm | installing pyright, ts_ls, prettier |
| pip | downloading pynvim, black, debugpy as wheels |
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
- Clone lazy.nvim and all plugins into `vendor/plugins/`
- Download the latest clangd release binary into `vendor/lsp/clangd/`
- Download the latest OmniSharp-Roslyn release into `vendor/lsp/omnisharp/`
- Install pyright, typescript-language-server, and prettier via npm into `vendor/lsp/`
- Compile tree-sitter parsers and copy the files to `vendor/parsers/`
- Download pynvim, black, and debugpy as pip wheels into `vendor/wheels/`
- Download the latest stylua binary into `vendor/formatters/`
- Download ripgrep into `vendor/ripgrep/`
- Download lazygit into `vendor/lazygit/`

Running fetch.ps1 a second time is safe — already-present items are skipped.

### Step 2 — transfer

Copy the entire directory (including `vendor/`) to the offline machine. A USB
drive, a network share that is accessible only for the copy, or any other
method works. The directory is typically 500 MB–1 GB.

### Step 3 — install (offline machine)

```powershell
cd custom-nvim
.\install.ps1
```

`install.ps1` will:
- Back up any existing `%LOCALAPPDATA%\nvim`
- Create a directory junction: `%LOCALAPPDATA%\nvim` -> this directory
- Install pynvim from `vendor/wheels/` with pip (`--no-index`, no network)
- Add to the user PATH: `vendor/formatters/stylua/`, `vendor/lsp/clangd/bin/`, `vendor/lazygit/`, `vendor/ripgrep/`

> PATH changes take effect in new terminal sessions. Open a fresh terminal after running install.ps1.

### Step 4 — verify

Run the included health check script:

```powershell
.\check.ps1
```

This checks all 34 items: vendor dirs, binaries, parsers, pip wheels, and
lazy plugin errors. All should report `OK`.

Then open Neovim and confirm interactively:

```
nvim
:Lazy          -- all plugins should show as loaded, no install button
:LspInfo       -- lists attached LSP servers for the current filetype
:checkhealth   -- overall health, including Python provider
```

---

## Plugin list

| Category | Plugins |
|----------|---------|
| Plugin manager | lazy.nvim |
| Colorscheme | tokyonight · catppuccin · kanagawa · rose-pine · nightfox · gruvbox · onedark |
| Statusline | lualine.nvim |
| File explorer | neo-tree.nvim |
| Fuzzy finder | telescope.nvim + plenary.nvim |
| Quick navigation | harpoon (v2) |
| Syntax / folds | nvim-treesitter + treesitter-textobjects |
| LSP client | nvim-lspconfig |
| Completion | nvim-cmp + 5 sources |
| Snippets | LuaSnip + friendly-snippets |
| Formatting | conform.nvim |
| Diagnostics panel | trouble.nvim |
| Debugger | nvim-dap + nvim-dap-ui + nvim-nio |
| Git decorations | gitsigns.nvim |
| Git diff viewer | diffview.nvim |
| Git TUI | lazygit.nvim |
| TODO highlights | todo-comments.nvim |
| Word highlights | vim-illuminate |
| Indent guides | indent-blankline.nvim |
| UI enhancement | noice.nvim |
| Auto-pairs | nvim-autopairs |
| Commenting | Comment.nvim |
| Surround | nvim-surround |
| Navigation | flash.nvim |
| Key hints | which-key.nvim |
| Notifications | nvim-notify |
| LSP progress | fidget.nvim |
| Color preview | nvim-colorizer.lua |
| Undo tree | undotree |
| Session persistence | persistence.nvim |
| Code outline | aerial.nvim |
| Sticky context | nvim-treesitter-context |

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

### Solution tree (VS Solution Explorer)

| Key | Action |
|-----|--------|
| `<leader>S` | Toggle solution tree sidebar |

Inside the solution tree buffer:

| Key | Action |
|-----|--------|
| `<CR>` / `o` | Open file / collapse project node |
| `R` | Refresh tree |
| `q` | Close sidebar |
| `?` | Show help |

On startup, if Neovim is opened with a directory argument, a picker appears to
choose between loading a `.sln` file or opening neo-tree.

### Code outline (aerial)

| Key | Action |
|-----|--------|
| `<leader>o` | Toggle code outline sidebar |

### Harpoon

| Key | Action |
|-----|--------|
| `<leader>a` | Add current file to harpoon |
| `<leader>H` | Toggle harpoon menu |
| `<M-1>` – `<M-4>` | Jump to marked file 1–4 |

### Theme

| Key | Action |
|-----|--------|
| `<leader>ft` | `:ThemeSwitch` — live picker (30 variants, no restart needed) |

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
| `<leader>fc` | Commands |
| `<leader>fm` | Marks |
| `<leader>fT` | TODO comments |
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

### Trouble (diagnostics panel)

| Key | Action |
|-----|--------|
| `<leader>xd` | Document diagnostics |
| `<leader>xD` | Workspace diagnostics |
| `<leader>xq` | Quickfix list |
| `<leader>xl` | Location list |
| `<leader>xr` | LSP references |
| `<leader>xt` | TODO list |

### Git

| Key | Action |
|-----|--------|
| `]h / [h` | Next / previous hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>hd` | Diff this |
| `<leader>gc` | Git commits (Telescope) |
| `<leader>gb` | Git branches (Telescope) |
| `<leader>gs` | Git status (Telescope) |
| `<leader>gd` | Open diffview |
| `<leader>gD` | Close diffview |
| `<leader>gh` | File history (diffview) |
| `<leader>gH` | Repo history (diffview) |
| `<leader>gg` | LazyGit |
| `<leader>gG` | LazyGit (current file) |

### Debugger (DAP)

| Key | Action |
|-----|--------|
| `<F5>` | Continue / start |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dC` | Run to cursor |
| `<leader>dr` | Open REPL |
| `<leader>dl` | Run last |
| `<leader>du` | Toggle DAP UI |

### TODO comments

| Key | Action |
|-----|--------|
| `]t / [t` | Next / previous TODO |
| `<leader>fT` | Search TODOs (Telescope) |
| `<leader>xt` | TODO list (Trouble) |

### Session (persistence)

| Key | Action |
|-----|--------|
| `<leader>pr` | Restore session for current directory |
| `<leader>ps` | Select session |
| `<leader>pd` | Don't save session on exit |

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

#### C/C++ debugging (codelldb)

nvim-dap is configured to use codelldb for C/C++. Download it separately:

1. Get the latest release from [github.com/vadimcn/codelldb/releases](https://github.com/vadimcn/codelldb/releases) — pick `codelldb-x86_64-windows.vsix`
2. Rename `.vsix` to `.zip` and extract it
3. Place the extracted folder at `vendor/dap/codelldb/`

The adapter will be picked up automatically on next Neovim start.

### C#

omnisharp-roslyn runs via `dotnet vendor/lsp/omnisharp/OmniSharp.dll`. It
indexes the solution automatically when you open a `.cs` file. If there are
multiple `.sln` files, it may prompt for selection.

The **solution tree** sidebar (`<leader>S`) parses `.sln`, `.csproj`
(SDK-style and old-style), and `.vcxproj` files to display a VS
Solution Explorer-style project view. Open Neovim with a directory argument
to be prompted for which solution to load.

csharpier is not vendored. Install it once on the offline machine:

```powershell
dotnet tool install -g csharpier
```

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

#### Python debugging (debugpy)

Install debugpy from the vendored wheel:

```powershell
pip install debugpy --no-index --find-links vendor\wheels\
```

Then press `<F5>` in any `.py` file to start debugging.

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

## Customization

### Changing the theme

All theme settings live in one file: **`lua/core/theme.lua`**.

**Quickest way:** press `<leader>ft` inside Neovim to open the live picker.
It applies the selected theme immediately and saves `theme.lua` automatically.

**Manual way:** open `lua/core/theme.lua`, replace the `return { ... }` block
with the recipe for your chosen theme (all recipes are in the comments at the
top of that file), save, and restart Neovim.

No internet access required — all themes below are pre-vendored.

#### Available vendored themes

| Theme | Styles / variants | lualine value |
|-------|-------------------|---------------|
| **tokyonight** | `night` `storm` `moon` `day` | `"tokyonight"` |
| **catppuccin** | `latte` `frappe` `macchiato` `mocha` | `"catppuccin"` |
| **kanagawa** | `wave` `dragon` `lotus` | `"kanagawa"` |
| **rose-pine** (default) | `main` `moon` `dawn` | `"rose-pine"` |
| **nightfox** | `nightfox` `dayfox` `dawnfox` `duskfox` `nordfox` `carbonfox` `terafox` | same as `name` |
| **gruvbox** | contrast: ` ` `soft` `hard` | `"gruvbox"` |
| **onedark** | `dark` `darker` `cool` `deep` `warm` `warmer` `light` | `"onedark"` |

#### Example: switch to catppuccin mocha

```lua
-- lua/core/theme.lua
return {
    plugin    = "catppuccin/nvim",
    lazy_name = "catppuccin",        -- needed because the repo is named "nvim"
    name      = "catppuccin-mocha",
    module    = "catppuccin",
    opts      = { flavour = "mocha" },
    lualine   = "catppuccin",
}
```

> `lazy_name` is only required for catppuccin and rose-pine, whose GitHub
> repo names (`nvim`, `neovim`) differ from their plugin directory names.

#### Adding a theme that is not vendored

1. Add an entry to the `$plugins` array in `fetch.ps1`.
2. Run `fetch.ps1` on an internet machine and re-transfer the new plugin
   directory (or the whole `vendor/`) to the offline machine.
3. Fill in `lua/core/theme.lua` and restart Neovim.

---

## Updating

On a machine with internet access, run `fetch.ps1` again. It will clone the
latest commits for every plugin and re-download LSP binaries and tools only if
they are missing (delete the target directory first to force a re-download).
Then transfer the updated `vendor/` to offline machines and run `.\check.ps1`
to verify.

---

## Troubleshooting

**Run the health check first**
```powershell
.\check.ps1
```
This catches most issues — missing binaries, parsers, and plugin errors — in
one pass.

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
Neovim and run `:TSInstall <language>` with `parser_install_dir` pointing
to `vendor/parsers/`, then copy the new file to the offline machine.

**clangd does not find MSVC headers**
Launch Neovim from a Developer PowerShell (search "Developer PowerShell for
VS 2022" in the Start menu). Alternatively, use a `.clangd` file to pass
explicit include paths.

**pynvim install fails offline**
Ensure `vendor/wheels/` contains `pynvim`, `msgpack`, and `greenlet` wheels.
If they are missing, re-run `fetch.ps1` on the internet machine.

**Telescope find files returns no results**
`rg` must be on PATH. Run `.\install.ps1` to add `vendor/ripgrep/` to the
user PATH, then open a fresh terminal.

**lazygit not found**
Run `.\install.ps1` to add `vendor/lazygit/` to the user PATH, then open a
fresh terminal.

**DAP: Python debugger not working**
Install debugpy from the vendored wheel:
```powershell
pip install debugpy --no-index --find-links vendor\wheels\
```

**DAP: C/C++ debugger not working**
codelldb is not included in vendor/. Download it from
[github.com/vadimcn/codelldb/releases](https://github.com/vadimcn/codelldb/releases)
and place it at `vendor/dap/codelldb/` (see Language-specific notes above).
