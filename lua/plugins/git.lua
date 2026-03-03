return {
    -- Side-by-side diff viewer and file history
    {
        "sindrets/diffview.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd  = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
        keys = {
            { "<leader>gd", "<cmd>DiffviewOpen<cr>",          desc = "Git: diff view"      },
            { "<leader>gD", "<cmd>DiffviewClose<cr>",         desc = "Git: close diff view" },
            { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git: file history"   },
            { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",   desc = "Git: repo history"   },
        },
        config = function()
            require("diffview").setup({
                -- Text-only icons, no Nerd Font required
                icons = { folder_closed = ">", folder_open = "v" },
                signs = { fold_closed = ">", fold_open = "v", done = "*" },
            })
        end,
    },

    -- Lazygit TUI inside a floating terminal
    -- Requires lazygit binary (vendored to vendor/lazygit/ by fetch.ps1,
    -- added to PATH by install.ps1).
    {
        "kdheepak/lazygit.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd  = { "LazyGit", "LazyGitCurrentFile" },
        keys = {
            { "<leader>gg", "<cmd>LazyGit<cr>",            desc = "Git: LazyGit"          },
            { "<leader>gG", "<cmd>LazyGitCurrentFile<cr>", desc = "Git: LazyGit (file)"   },
        },
        config = function()
            vim.g.lazygit_floating_window_scaling_factor = 0.9
            vim.g.lazygit_use_neovim_remote = false
        end,
    },
}
