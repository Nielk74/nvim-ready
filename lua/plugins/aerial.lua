return {
    {
        "stevearc/aerial.nvim",
        event = "LspAttach",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Toggle outline (aerial)" },
        },
        config = function()
            require("aerial").setup({
                attach_mode = "cursor",
                layout = {
                    min_width = 28,
                },
            })
        end,
    },
}
