return {
    {
        "folke/trouble.nvim",
        cmd  = "Trouble",
        keys = {
            { "<leader>xd", "<cmd>Trouble diagnostics filter.buf=0 toggle<cr>", desc = "Trouble: document diagnostics" },
            { "<leader>xD", "<cmd>Trouble diagnostics toggle<cr>",              desc = "Trouble: workspace diagnostics" },
            { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                   desc = "Trouble: quickfix list" },
            { "<leader>xl", "<cmd>Trouble loclist toggle<cr>",                  desc = "Trouble: location list" },
            { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>",           desc = "Trouble: LSP references" },
            { "<leader>xt", "<cmd>Trouble todo toggle<cr>",                     desc = "Trouble: TODOs" },
        },
        config = function()
            require("trouble").setup({
                icons = {
                    indent        = { middle = " ", last = " ", top = " ", ws = "  " },
                    folder_closed = ">",
                    folder_open   = "v",
                    kinds = {},   -- disable kind icons (no Nerd Font)
                },
            })
        end,
    },
}
