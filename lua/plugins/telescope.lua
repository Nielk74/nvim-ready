return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<cr>",                desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<cr>",                 desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<cr>",                   desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<cr>",                 desc = "Help tags" },
            { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                  desc = "Recent files" },
            { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>",      desc = "Document symbols" },
            { "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>",     desc = "Workspace symbols" },
            { "<leader>fd", "<cmd>Telescope diagnostics<cr>",               desc = "Diagnostics" },
            { "<leader>fm", "<cmd>Telescope marks<cr>",                     desc = "Marks" },
            { "<leader>fc", "<cmd>Telescope commands<cr>",                  desc = "Commands" },
            { "<leader>fk", "<cmd>Telescope keymaps<cr>",                   desc = "Keymaps" },
            { "<leader>gc", "<cmd>Telescope git_commits<cr>",               desc = "Git commits" },
            { "<leader>gb", "<cmd>Telescope git_branches<cr>",              desc = "Git branches" },
            { "<leader>gs", "<cmd>Telescope git_status<cr>",                desc = "Git status" },
            { "<leader>/",  "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search in buffer" },
        },
        config = function()
            local telescope = require("telescope")
            local actions   = require("telescope.actions")

            telescope.setup({
                defaults = {
                    prompt_prefix    = "> ",
                    selection_caret  = "> ",
                    path_display     = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_strategy  = "horizontal",
                    layout_config = {
                        horizontal = {
                            prompt_position = "top",
                            preview_width   = 0.55,
                        },
                        width  = 0.87,
                        height = 0.80,
                    },
                    file_ignore_patterns = {
                        "%.git/", "node_modules/", "%.cache/",
                        "build/", "dist/", "%.obj$", "%.o$",
                    },
                    mappings = {
                        i = {
                            ["<C-j>"]   = actions.move_selection_next,
                            ["<C-k>"]   = actions.move_selection_prev,
                            ["<C-q>"]   = actions.send_selected_to_qflist + actions.open_qflist,
                            ["<C-a>"]   = actions.select_all,
                            ["<Esc>"]   = actions.close,
                            ["<C-u>"]   = false,   -- keep default: clear prompt
                        },
                    },
                },
                pickers = {
                    find_files = {
                        -- ripgrep as backend so fd is not required
                        find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
                    },
                    live_grep = {
                        additional_args = { "--hidden" },
                    },
                },
            })
        end,
    },
}
