-- LSP configuration — fully offline, no mason.
-- Binaries are expected in vendor/lsp/ (populated by fetch.ps1).
--
-- Layout expected after fetch.ps1:
--   vendor/lsp/clangd/bin/clangd.exe
--   vendor/lsp/omnisharp/OmniSharp.dll
--   vendor/lsp/pyright/node_modules/.bin/pyright-langserver.cmd
--   vendor/lsp/ts_ls/node_modules/.bin/typescript-language-server.cmd

local vendor_lsp = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "lsp")

local bin = {
    clangd   = vim.fs.joinpath(vendor_lsp, "clangd",  "bin",            "clangd.exe"),
    omnisharp = vim.fs.joinpath(vendor_lsp, "omnisharp", "OmniSharp.dll"),
    pyright  = vim.fs.joinpath(vendor_lsp, "pyright", "node_modules",
                               ".bin", "pyright-langserver.cmd"),
    ts_ls    = vim.fs.joinpath(vendor_lsp, "ts_ls",   "node_modules",
                               ".bin", "typescript-language-server.cmd"),
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
            local lspconfig    = require("lspconfig")
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

            -- C / C++ -------------------------------------------------------
            -- clangd reads compile_commands.json from the project root.
            -- Generate it with: cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ...
            -- For MSVC headers, launch Neovim from a Developer PowerShell.
            lspconfig.clangd.setup({
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
                capabilities = (function()
                    local caps = require("cmp_nvim_lsp").default_capabilities()
                    caps.offsetEncoding = { "utf-16" }
                    return caps
                end)(),
                on_attach = on_attach,
                init_options = {
                    usePlaceholders    = true,
                    completeUnimported = true,
                    clangdFileStatus   = true,
                },
            })

            -- C# ------------------------------------------------------------
            lspconfig.omnisharp.setup({
                cmd          = { "dotnet", bin.omnisharp },
                capabilities = capabilities,
                on_attach    = on_attach,
                enable_roslyn_analyzers      = true,
                organize_imports_on_format   = true,
                enable_import_completion     = true,
                enable_editor_config_support = true,
            })

            -- Python --------------------------------------------------------
            lspconfig.pyright.setup({
                cmd          = { bin.pyright, "--stdio" },
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

            -- TypeScript / JavaScript ---------------------------------------
            lspconfig.ts_ls.setup({
                cmd          = { bin.ts_ls, "--stdio" },
                capabilities = capabilities,
                on_attach    = on_attach,
                init_options = {
                    hostInfo = "neovim",
                },
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints            = "all",
                            includeInlayFunctionParameterTypeHints    = true,
                            includeInlayVariableTypeHints             = true,
                            includeInlayPropertyDeclarationTypeHints  = true,
                            includeInlayFunctionLikeReturnTypeHints   = true,
                        },
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = "all",
                        },
                    },
                },
            })
        end,
    },
}
