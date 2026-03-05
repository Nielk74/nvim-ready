-- LSP configuration — fully offline, no mason.
-- Uses Nvim 0.11 native API: vim.lsp.config() + vim.lsp.enable()
-- Binaries are expected in vendor/lsp/ (populated by fetch.ps1).
--
-- Layout expected after fetch.ps1:
--   vendor/lsp/clangd/bin/clangd.exe
--   vendor/lsp/omnisharp/OmniSharp.dll
--   vendor/lsp/pyright/node_modules/.bin/pyright-langserver.cmd
--   vendor/lsp/ts_ls/node_modules/.bin/typescript-language-server.cmd

local vendor_lsp = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "lsp")

local bin = {
    clangd    = vim.fs.joinpath(vendor_lsp, "clangd",  "bin",        "clangd.exe"),
    omnisharp = vim.fs.joinpath(vendor_lsp, "omnisharp", "OmniSharp.dll"),
    pyright   = vim.fs.joinpath(vendor_lsp, "pyright", "node_modules", ".bin", "pyright-langserver.cmd"),
    ts_ls     = vim.fs.joinpath(vendor_lsp, "ts_ls",   "node_modules", ".bin", "typescript-language-server.cmd"),
}

-- Warn once per session if a binary is missing rather than silently failing.
for name, path in pairs(bin) do
    if not vim.uv.fs_stat(path) then
        vim.notify(
            string.format("[LSP] %s binary not found:\n  %s\nRun fetch.ps1.", name, path),
            vim.log.levels.WARN
        )
    end
end

local function on_attach(_, bufnr)
    local map = function(keys, func, desc)
        vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
    end

    map("gd",         function() require("telescope.builtin").lsp_definitions() end,      "Go to definition")
    map("gD",         vim.lsp.buf.declaration,     "Go to declaration")
    map("gr",         function() require("telescope.builtin").lsp_references() end,        "References")
    map("gi",         function() require("telescope.builtin").lsp_implementations() end,   "Go to implementation")
    map("gt",         function() require("telescope.builtin").lsp_type_definitions() end,  "Go to type definition")
    map("K",          vim.lsp.buf.hover,           "Hover documentation")
    map("<C-s>",      vim.lsp.buf.signature_help,  "Signature help")
    map("<leader>rn", vim.lsp.buf.rename,          "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action,     "Code action")
    map("<leader>lf", function()
        vim.lsp.buf.format({ async = true })
    end, "Format buffer (LSP)")
    map("<leader>li", "<cmd>LspInfo<cr>",    "LSP info")
    map("<leader>lr", "<cmd>LspRestart<cr>", "Restart LSP")

    vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help,
        { buffer = bufnr, desc = "LSP: Signature help" })
end

return {
    {
        "neovim/nvim-lspconfig",
        -- loaded once the first real buffer opens
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "hrsh7th/cmp-nvim-lsp", "p00f/clangd_extensions.nvim" },
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            vim.lsp.handlers["textDocument/hover"] =
                vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
            vim.lsp.handlers["textDocument/signatureHelp"] =
                vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

            vim.diagnostic.config({
                virtual_text     = { prefix = ">" },
                signs            = true,
                underline        = true,
                update_in_insert = false,
                severity_sort    = true,
                float            = { border = "rounded", source = "always" },
            })

            -- ----------------------------------------------------------------
            -- C / C++ — clangd
            -- clangd reads compile_commands.json from the project root.
            -- Generate it via cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
            -- or via tools like compiledb / bear.
            -- For MSVC headers, launch Neovim from a Developer PowerShell.
            -- ----------------------------------------------------------------
            -- clangd_extensions: inlay hints and C++ extras on top of clangd.
            -- Setup must come before vim.lsp.enable() so the plugin can register
            -- its on_attach hook before any clangd client starts.
            -- Guard: if the plugin failed to load (e.g. lazy ordering issue),
            -- warn once rather than erroring silently.
            local ok_ext = pcall(function()
                require("clangd_extensions").setup({
                    inlay_hints = {
                        inline            = true,
                        only_current_line = false,
                    },
                })
            end)
            if not ok_ext then
                vim.notify(
                    "[LSP] clangd_extensions not loaded — inlay hints disabled",
                    vim.log.levels.WARN
                )
            end

            vim.lsp.config("clangd", {
                cmd = {
                    bin.clangd,
                    "--background-index",
                    "--clang-tidy",
                    "--header-insertion=iwyu",
                    "--completion-style=detailed",
                    "--function-arg-placeholders",
                    "--fallback-style=Microsoft",
                    "--query-driver=**",
                    "-j=4",
                },
                filetypes    = { "c", "cpp", "objc", "objcpp" },
                root_markers = {
                    ".clangd",
                    ".clang-tidy",
                    ".clang-format",
                    "compile_commands.json",
                    "compile_flags.txt",
                    ".git",
                },
                capabilities = vim.tbl_deep_extend("force", capabilities, {
                    offsetEncoding = { "utf-16" },
                    textDocument   = { completion = { editsNearCursor = true } },
                }),
                on_attach = on_attach,
                -- Update offset encoding from the server's initialize response.
                on_init = function(client, init_result)
                    if init_result.offsetEncoding then
                        client.offset_encoding = init_result.offsetEncoding
                    end
                end,
                init_options = {
                    usePlaceholders    = true,
                    completeUnimported = true,
                    clangdFileStatus   = true,
                },
            })

            -- ----------------------------------------------------------------
            -- C# — OmniSharp-Roslyn
            -- root_dir is computed per-buffer by the FileType autocmd below,
            -- which walks upward for .sln files and prompts when multiple are
            -- found (caching the user's choice for the session).
            -- OmniSharp is NOT included in vim.lsp.enable(); the autocmd
            -- handles attachment after computing the correct root.
            -- Settings go in the `settings` table (Nvim 0.11 sends them via
            -- workspace/didChangeConfiguration on attach).
            -- The cmd flags (-z, --hostPID, --languageserver) are required
            -- explicitly since we bypass the lspconfig wrapper.
            -- ----------------------------------------------------------------

            -- Helpers for .sln detection (mirrors solution_tree.lua logic).
            local function lsp_norm(p) return (p:gsub("\\", "/")) end

            local function find_slns_upward(start_dir)
                local dir = lsp_norm(vim.fn.fnamemodify(start_dir, ":p"):gsub("[/\\]$", ""))
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

            -- Session cache: sln search dir → chosen root dir.
            local omnisharp_root_cache = {}

            local omnisharp_cfg = {
                name = "omnisharp",
                cmd = {
                    "dotnet", bin.omnisharp,
                    "-z",                                         -- https://github.com/OmniSharp/omnisharp-vscode/pull/4300
                    "--hostPID", tostring(vim.fn.getpid()),
                    "DotNet:enablePackageRestore=false",
                    "--encoding", "utf-8",
                    "--languageserver",
                },
                filetypes    = { "cs", "vb" },
                capabilities = vim.tbl_deep_extend("force", capabilities, {
                    -- OmniSharp doesn't support workspace folders properly.
                    workspace = { workspaceFolders = false },
                }),
                on_attach = on_attach,
                settings = {
                    FormattingOptions = {
                        EnableEditorConfigSupport = true,
                        OrganizeImports           = true,
                    },
                    MsBuild = {
                        -- Only load projects for files currently open.
                        -- Dramatically reduces startup noise on large solutions.
                        LoadProjectsOnDemand = true,
                    },
                    RoslynExtensionsOptions = {
                        EnableAnalyzersSupport   = true,
                        EnableImportCompletion   = true,
                        -- Only run analyzers on open documents (less noise).
                        AnalyzeOpenDocumentsOnly = true,
                    },
                    Sdk = {
                        IncludePrereleases = true,
                    },
                },
            }

            -- Register config for LspInfo / :LspRestart compatibility.
            -- Root detection is handled by the FileType autocmd below.
            vim.lsp.config("omnisharp", omnisharp_cfg)

            vim.api.nvim_create_autocmd("FileType", {
                pattern  = { "cs", "vb" },
                callback = function(ev)
                    local fname = vim.api.nvim_buf_get_name(ev.buf)
                    if fname == "" then return end

                    local file_dir = lsp_norm(vim.fs.dirname(fname))
                    local slns, sln_dir = find_slns_upward(file_dir)

                    local function start_omnisharp(root)
                        vim.lsp.start(
                            vim.tbl_extend("force", omnisharp_cfg, { root_dir = root }),
                            { bufnr = ev.buf }
                        )
                    end

                    -- No .sln found: fall back to .git root or file directory.
                    if #slns == 0 then
                        local git = vim.fs.find(".git", { path = file_dir, upward = true })[1]
                        start_omnisharp(git and lsp_norm(vim.fs.dirname(git)) or file_dir)
                        return
                    end

                    -- Exactly one .sln: use it directly.
                    if #slns == 1 then
                        start_omnisharp(sln_dir)
                        return
                    end

                    -- Multiple .sln files: use cached choice if already decided.
                    if omnisharp_root_cache[sln_dir] then
                        start_omnisharp(omnisharp_root_cache[sln_dir])
                        return
                    end

                    -- Align with solution_tree if it already has an active .sln.
                    local ok_st, st = pcall(require, "solution_tree")
                    if ok_st and st.active_sln then
                        local active = st.active_sln()
                        if active then
                            local active_dir = lsp_norm(vim.fs.dirname(active))
                            for _, sln in ipairs(slns) do
                                if lsp_norm(vim.fs.dirname(sln)) == active_dir then
                                    omnisharp_root_cache[sln_dir] = active_dir
                                    start_omnisharp(active_dir)
                                    return
                                end
                            end
                        end
                    end

                    -- Default: start with first .sln, then prompt user to confirm or change.
                    omnisharp_root_cache[sln_dir] = sln_dir
                    start_omnisharp(sln_dir)

                    vim.schedule(function()
                        local labels = vim.tbl_map(function(s)
                            return vim.fn.fnamemodify(s, ":t")
                        end, slns)
                        vim.ui.select(labels, { prompt = "OmniSharp: select solution:" }, function(_, idx)
                            if not idx then return end
                            local chosen_dir = lsp_norm(vim.fs.dirname(slns[idx]))
                            if chosen_dir == omnisharp_root_cache[sln_dir] then return end

                            omnisharp_root_cache[sln_dir] = chosen_dir

                            -- Stop existing clients then re-attach all open cs/vb buffers.
                            for _, client in pairs(vim.lsp.get_clients({ name = "omnisharp" })) do
                                client.stop()
                            end
                            vim.schedule(function()
                                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                                    if vim.api.nvim_buf_is_loaded(bufnr) then
                                        local ft = vim.bo[bufnr].filetype
                                        if ft == "cs" or ft == "vb" then
                                            local bname = vim.api.nvim_buf_get_name(bufnr)
                                            if bname ~= "" then
                                                vim.lsp.start(
                                                    vim.tbl_extend("force", omnisharp_cfg,
                                                        { root_dir = chosen_dir }),
                                                    { bufnr = bufnr }
                                                )
                                            end
                                        end
                                    end
                                end
                            end)

                            -- Align solution_tree sidebar with the chosen solution.
                            if ok_st then
                                pcall(st.open, slns[idx])
                            end
                        end)
                    end)
                end,
            })

            -- ----------------------------------------------------------------
            -- Python — Pyright
            -- ----------------------------------------------------------------
            vim.lsp.config("pyright", {
                cmd          = { bin.pyright, "--stdio" },
                filetypes    = { "python" },
                root_markers = {
                    "pyproject.toml",
                    "setup.py",
                    "setup.cfg",
                    "requirements.txt",
                    "pyrightconfig.json",
                    ".git",
                },
                capabilities = capabilities,
                on_attach    = on_attach,
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode       = "standard",
                            autoSearchPaths        = true,
                            useLibraryCodeForTypes = true,
                            diagnosticMode         = "workspace",
                        },
                    },
                },
            })

            -- ----------------------------------------------------------------
            -- TypeScript / JavaScript — ts_ls
            -- ----------------------------------------------------------------
            vim.lsp.config("ts_ls", {
                cmd          = { bin.ts_ls, "--stdio" },
                filetypes    = {
                    "javascript", "javascriptreact", "javascript.jsx",
                    "typescript", "typescriptreact", "typescript.tsx",
                },
                root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
                capabilities = capabilities,
                on_attach    = on_attach,
                init_options = { hostInfo = "neovim" },
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints           = "all",
                            includeInlayFunctionParameterTypeHints   = true,
                            includeInlayVariableTypeHints            = true,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints  = true,
                        },
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = "all",
                        },
                    },
                },
            })

            -- Start servers automatically on matching filetypes.
            -- OmniSharp is excluded: its FileType autocmd above handles
            -- attachment after computing the correct root_dir per buffer.
            vim.lsp.enable({ "clangd", "pyright", "ts_ls" })
        end,
    },
}
