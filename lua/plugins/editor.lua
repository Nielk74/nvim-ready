return {
    -- Auto-close brackets / quotes
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        dependencies = { "hrsh7th/nvim-cmp" },
        config = function()
            require("nvim-autopairs").setup({
                check_ts   = true,
                ts_config  = {
                    lua  = { "string" },
                    javascript = { "template_string" },
                },
            })
            -- Wire into nvim-cmp so confirmed items get closing pair
            local ok_cmp, cmp = pcall(require, "cmp")
            local ok_ap,  ap  = pcall(require, "nvim-autopairs.completion.cmp")
            if ok_cmp and ok_ap then
                cmp.event:on("confirm_done", ap.on_confirm_done())
            end
        end,
    },

    -- Commenting: gcc / gbc / gc in visual mode
    {
        "numToStr/Comment.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
        config = function()
            require("Comment").setup({
                pre_hook = function(ctx)
                    local ok, ts_context = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
                    if ok then
                        return ts_context.create_pre_hook()(ctx)
                    end
                end,
            })
        end,
    },

    -- Code formatting — all formatters resolved from vendor/ or system PATH.
    -- Binaries expected (populated by fetch.ps1):
    --   vendor/formatters/stylua/stylua.exe          (added to PATH by install.ps1)
    --   vendor/lsp/clangd/bin/clang-format.exe       (added to PATH by install.ps1)
    -- System-wide (install separately):
    --   black      -> pip install black --no-index --find-links vendor\wheels\
    --   prettier   -> bundled inside vendor/lsp/ts_ls/node_modules/.bin/
    --   csharpier  -> dotnet tool install csharpier (requires .NET)
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        keys = {
            {
                "<leader>lF",
                function()
                    require("conform").format({ async = true, lsp_fallback = true })
                end,
                desc = "LSP: Format (conform)",
            },
        },
        config = function()
            local vendor = vim.fn.stdpath("config") .. "/vendor"

            -- prettier is bundled inside the ts_ls node_modules
            local prettier_bin = vendor .. "/lsp/ts_ls/node_modules/.bin/prettier.cmd"

            require("conform").setup({
                -- Register the vendored prettier binary explicitly
                formatters = {
                    prettier = {
                        command = prettier_bin,
                    },
                },
                formatters_by_ft = {
                    lua              = { "stylua" },
                    python           = { "black" },
                    typescript       = { "prettier" },
                    javascript       = { "prettier" },
                    typescriptreact  = { "prettier" },
                    javascriptreact  = { "prettier" },
                    json             = { "prettier" },
                    jsonc            = { "prettier" },
                    html             = { "prettier" },
                    css              = { "prettier" },
                    scss             = { "prettier" },
                    cpp              = { "clang_format" },
                    c                = { "clang_format" },
                    cs               = { "csharpier" },
                },
                format_on_save = {
                    timeout_ms   = 1000,
                    lsp_fallback = true,
                },
                notify_on_error = false,   -- silently skip missing formatters
            })
        end,
    },

    -- Surround text objects: ys, cs, ds  (e.g. ysiw" to surround word with quotes)
    {
        "kylechui/nvim-surround",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup()
        end,
    },

    -- Better f/t motions and multi-line search
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        keys = {
            { "s",     function() require("flash").jump()   end, desc = "Flash jump",   mode = { "n", "x", "o" } },
            { "S",     function() require("flash").treesitter() end, desc = "Flash treesitter", mode = { "n", "x", "o" } },
            { "r",     function() require("flash").remote() end, desc = "Flash remote", mode = "o" },
            { "<C-s>", function() require("flash").toggle() end, desc = "Flash toggle", mode = "c" },
        },
        config = function()
            require("flash").setup()
        end,
    },

    -- Show color chips inline for CSS / hex values
    {
        "NvChad/nvim-colorizer.lua",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("colorizer").setup({
                filetypes = { "css", "scss", "html", "javascript", "typescript",
                              "typescriptreact", "javascriptreact", "lua" },
                user_default_options = { mode = "background", names = false },
            })
        end,
    },

    -- Persistent undo tree visualization
    {
        "mbbill/undotree",
        keys = {
            { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
        },
    },

    -- Show LSP progress in the status area
    {
        "j-hui/fidget.nvim",
        event = "LspAttach",
        config = function()
            require("fidget").setup({
                notification = {
                    window = { winblend = 0 },
                },
            })
        end,
    },

    -- Highlight TODO / FIXME / HACK / NOTE / WARN comments
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        event = { "BufReadPre", "BufNewFile" },
        keys = {
            { "]t",         function() require("todo-comments").jump_next() end, desc = "Next TODO" },
            { "[t",         function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
            { "<leader>fT", "<cmd>TodoTelescope<cr>",                            desc = "Find TODOs" },
        },
        config = function()
            require("todo-comments").setup()
        end,
    },

    -- Highlight all occurrences of the word under the cursor
    {
        "RRethy/vim-illuminate",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("illuminate").configure({
                delay             = 100,
                large_file_cutoff = 2000,
                filetypes_denylist = { "neo-tree", "TelescopePrompt", "Trouble", "lazy", "help" },
            })
        end,
    },

    -- Session persistence: auto-save on exit, restore per working directory
    {
        "folke/persistence.nvim",
        event = "BufReadPre",
        keys = {
            { "<leader>pr", function() require("persistence").load() end,   desc = "Session: restore" },
            { "<leader>ps", function() require("persistence").select() end, desc = "Session: select"  },
            { "<leader>pd", function() require("persistence").stop() end,   desc = "Session: don't save" },
        },
        config = function()
            require("persistence").setup({
                dir = vim.fn.stdpath("state") .. "/sessions/",
            })
        end,
    },
}
