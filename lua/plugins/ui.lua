local T = require("core.theme")

return {
    -- Colorscheme — configured in lua/core/theme.lua
    {
        T.plugin,
        lazy     = false,
        priority = 1000,
        config = function()
            require(T.module).setup(T.opts)
            vim.cmd.colorscheme(T.name)
        end,
    },

    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        config = function()
            local function lsp_name()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then return "no LSP" end
                local names = {}
                for _, c in ipairs(clients) do
                    table.insert(names, c.name)
                end
                return table.concat(names, ", ")
            end

            require("lualine").setup({
                options = {
                    theme            = T.lualine,
                    globalstatus     = true,
                    component_separators = { left = "|", right = "|" },
                    section_separators  = { left = "",  right = ""  },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { lsp_name, "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
                inactive_sections = {
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "location" },
                },
            })
        end,
    },

    -- File explorer
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
        },
        keys = {
            { "<leader>e",  "<cmd>Neotree toggle<cr>",       desc = "Toggle file explorer" },
            { "<leader>E",  "<cmd>Neotree reveal<cr>",       desc = "Reveal in explorer"   },
            { "<leader>be", "<cmd>Neotree buffers reveal float<cr>", desc = "Buffer list"  },
        },
        config = function()
            require("neo-tree").setup({
                close_if_last_window = true,
                window = { width = 30 },
                default_component_configs = {
                    -- Text-only indicators, no icon fonts required
                    icon = {
                        folder_closed = ">",
                        folder_open   = "v",
                        folder_empty  = "-",
                        default       = "*",
                    },
                    git_status = {
                        symbols = {
                            added     = "+",
                            modified  = "~",
                            deleted   = "-",
                            renamed   = "->",
                            untracked = "?",
                            ignored   = "!",
                            unstaged  = "u",
                            staged    = "s",
                            conflict  = "x",
                        },
                    },
                },
                filesystem = {
                    filtered_items = {
                        visible      = true,
                        hide_dotfiles = false,
                        hide_gitignored = false,
                    },
                    follow_current_file = { enabled = true },
                    use_libuv_file_watcher = true,
                },
            })
        end,
    },

    -- Git signs in the gutter
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup({
                signs = {
                    add          = { text = "+" },
                    change       = { text = "~" },
                    delete       = { text = "_" },
                    topdelete    = { text = "^" },
                    changedelete = { text = ">" },
                    untracked    = { text = "?" },
                },
                on_attach = function(bufnr)
                    local gs  = package.loaded.gitsigns
                    local map = function(keys, func, desc)
                        vim.keymap.set("n", keys, func,
                            { buffer = bufnr, desc = "Git: " .. desc })
                    end
                    -- Navigation
                    map("]h", function()
                        if vim.wo.diff then return "]c" end
                        gs.next_hunk()
                    end, "Next hunk")
                    map("[h", function()
                        if vim.wo.diff then return "[c" end
                        gs.prev_hunk()
                    end, "Previous hunk")
                    -- Actions
                    map("<leader>hs",  gs.stage_hunk,        "Stage hunk")
                    map("<leader>hr",  gs.reset_hunk,        "Reset hunk")
                    map("<leader>hS",  gs.stage_buffer,      "Stage buffer")
                    map("<leader>hp",  gs.preview_hunk,      "Preview hunk")
                    map("<leader>hb",  gs.blame_line,        "Blame line")
                    map("<leader>hd",  gs.diffthis,          "Diff this")
                end,
            })
        end,
    },

    -- Indent guides
    {
        "lukas-reineke/indent-blankline.nvim",
        main  = "ibl",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("ibl").setup({
                indent = { char = "│" },
                scope  = { enabled = true, show_start = false },
            })
        end,
    },

    -- Key hint popup
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")
            wk.setup({ delay = 400 })
            -- Register group labels
            wk.add({
                { "<leader>f",  group = "find (telescope)" },
                { "<leader>g",  group = "git" },
                { "<leader>h",  group = "hunk (git)" },
                { "<leader>l",  group = "lsp" },
                { "<leader>d",  group = "diagnostics" },
                { "<leader>b",  group = "buffer" },
                { "<leader>s",  group = "split" },
                { "<leader>t",  group = "treesitter" },
                { "<leader>c",  group = "quickfix" },
                { "<leader>r",  group = "refactor" },
            })
        end,
    },

    -- Better notifications and UI hooks
    {
        "rcarriga/nvim-notify",
        lazy = false,
        priority = 999,
        config = function()
            local notify = require("notify")
            notify.setup({
                render   = "minimal",
                stages   = "fade",
                timeout  = 3000,
                max_width = 60,
            })
            vim.notify = notify
        end,
    },
}
