return {
    {
        "ThePrimeagen/harpoon",
        branch       = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>a",  desc = "Harpoon: add file"       },
            { "<leader>H",  desc = "Harpoon: toggle menu"    },
            { "<M-1>",      desc = "Harpoon: file 1"         },
            { "<M-2>",      desc = "Harpoon: file 2"         },
            { "<M-3>",      desc = "Harpoon: file 3"         },
            { "<M-4>",      desc = "Harpoon: file 4"         },
        },
        config = function()
            local harpoon = require("harpoon")
            harpoon:setup()

            vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end,
                { desc = "Harpoon: add file" })

            vim.keymap.set("n", "<leader>H", function()
                harpoon.ui:toggle_quick_menu(harpoon:list())
            end, { desc = "Harpoon: toggle menu" })

            vim.keymap.set("n", "<M-1>", function() harpoon:list():select(1) end,
                { desc = "Harpoon: file 1" })
            vim.keymap.set("n", "<M-2>", function() harpoon:list():select(2) end,
                { desc = "Harpoon: file 2" })
            vim.keymap.set("n", "<M-3>", function() harpoon:list():select(3) end,
                { desc = "Harpoon: file 3" })
            vim.keymap.set("n", "<M-4>", function() harpoon:list():select(4) end,
                { desc = "Harpoon: file 4" })
        end,
    },
}
