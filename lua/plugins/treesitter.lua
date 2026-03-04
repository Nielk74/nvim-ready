-- Tree-sitter -- fully offline.
-- Compiled parser .so files live in vendor/parsers/parser/ (built by fetch.ps1).
-- auto_install and sync_install are both disabled; no compiler is invoked at
-- runtime on the offline machine.
--
-- NOTE: the new nvim-treesitter (0.10+) API is require('nvim-treesitter'),
-- NOT require('nvim-treesitter.configs'). The old .configs module is gone.
-- Text-object keymaps must be wired manually via module functions.

local vendor_parsers = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "parsers")

return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = false,   -- do not run TSUpdate on the offline machine
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
        },
        config = function()
            -- Point the install dir to vendor/parsers/ so nvim-treesitter
            -- finds the pre-compiled parsers there.
            require("nvim-treesitter").setup({
                install_dir = vendor_parsers,
            })

            -- Treesitter-based folding
            vim.opt.foldmethod = "expr"
            vim.opt.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
            vim.opt.foldlevel  = 99
        end,
    },

    -- Sticky context: pins the current function/class/namespace at the top
    -- when scrolled past it. Useful for large C++ and C# files.
    {
        "nvim-treesitter/nvim-treesitter-context",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("treesitter-context").setup({
                max_lines      = 3,
                trim_scope     = "outer",
            })
        end,
    },

    -- Text objects
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = { lookahead = true },
                move   = { set_jumps = true },
            })

            local select = require("nvim-treesitter-textobjects.select")
            local move   = require("nvim-treesitter-textobjects.move")
            local swap   = require("nvim-treesitter-textobjects.swap")
            local map    = vim.keymap.set

            -- Select text objects (visual and operator-pending modes)
            local sel = { "x", "o" }
            map(sel, "af", function() select.select_textobject("@function.outer", "textobjects") end, { desc = "TS: outer function" })
            map(sel, "if", function() select.select_textobject("@function.inner", "textobjects") end, { desc = "TS: inner function" })
            map(sel, "ac", function() select.select_textobject("@class.outer",    "textobjects") end, { desc = "TS: outer class"    })
            map(sel, "ic", function() select.select_textobject("@class.inner",    "textobjects") end, { desc = "TS: inner class"    })
            map(sel, "aa", function() select.select_textobject("@parameter.outer","textobjects") end, { desc = "TS: outer param"    })
            map(sel, "ia", function() select.select_textobject("@parameter.inner","textobjects") end, { desc = "TS: inner param"    })
            map(sel, "ab", function() select.select_textobject("@block.outer",    "textobjects") end, { desc = "TS: outer block"    })
            map(sel, "ib", function() select.select_textobject("@block.inner",    "textobjects") end, { desc = "TS: inner block"    })

            -- Navigate to next/previous function and class
            local nav = { "n", "x", "o" }
            map(nav, "]f", function() move.goto_next_start("@function.outer")     end, { desc = "TS: next function start"  })
            map(nav, "]F", function() move.goto_next_end("@function.outer")       end, { desc = "TS: next function end"    })
            map(nav, "[f", function() move.goto_previous_start("@function.outer") end, { desc = "TS: prev function start"  })
            map(nav, "[F", function() move.goto_previous_end("@function.outer")   end, { desc = "TS: prev function end"    })
            map(nav, "]c", function() move.goto_next_start("@class.outer")        end, { desc = "TS: next class start"     })
            map(nav, "]C", function() move.goto_next_end("@class.outer")          end, { desc = "TS: next class end"       })
            map(nav, "[c", function() move.goto_previous_start("@class.outer")    end, { desc = "TS: prev class start"     })
            map(nav, "[C", function() move.goto_previous_end("@class.outer")      end, { desc = "TS: prev class end"       })

            -- Swap adjacent parameters
            map("n", "<leader>tp", function() swap.swap_next("@parameter.inner")     end, { desc = "TS: swap next param"     })
            map("n", "<leader>tP", function() swap.swap_previous("@parameter.inner") end, { desc = "TS: swap previous param" })
        end,
    },
}
