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

    map("gd",         vim.lsp.buf.definition,      "Go to definition")
    map("gD",         vim.lsp.buf.declaration,     "Go to declaration")
    map("gr",         vim.lsp.buf.references,      "References")
    map("gi",         vim.lsp.buf.implementation,  "Go to implementation")
    map("gt",         vim.lsp.buf.type_definition, "Go to type definition")
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
        dependencies = { "hrsh7th/cmp-nvim-lsp" },
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
            vim.lsp.config("clangd", {
                cmd = {
                    bin.clangd,
                    "--background-index",
                    "--clang-tidy",
                    "--header-insertion=iwyu",
                    "--completion-style=detailed",
                    "--function-arg-placeholders",
                    "--fallback-style=Microsoft",
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
            -- OmniSharp finds the .sln automatically via root_markers.
            -- Settings go in the `settings` table (Nvim 0.11 sends them via
            -- workspace/didChangeConfiguration on attach).
            -- The cmd flags (-z, --hostPID, --languageserver) are required
            -- by the lspconfig on_new_config for older compat; here we set
            -- them explicitly since we bypass the lspconfig wrapper.
            -- ----------------------------------------------------------------
            vim.lsp.config("omnisharp", {
                cmd = {
                    "dotnet", bin.omnisharp,
                    "-z",                                         -- https://github.com/OmniSharp/omnisharp-vscode/pull/4300
                    "--hostPID", tostring(vim.fn.getpid()),
                    "DotNet:enablePackageRestore=false",
                    "--encoding", "utf-8",
                    "--languageserver",
                },
                filetypes    = { "cs", "vb" },
                -- Use a function so we can match *.sln glob patterns.
                root_markers = { "*.sln", "*.slnx", "*.csproj", "omnisharp.json", ".git" },
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

            -- Start all servers automatically on matching filetypes.
            vim.lsp.enable({ "clangd", "omnisharp", "pyright", "ts_ls" })
        end,
    },
}
