-- ============================================================
-- Theme configuration — edit this file to change the theme.
-- Restart Neovim after saving.
-- ============================================================

-- To switch to another colorscheme:
--   1. Clone the plugin into vendor/plugins/<repo-name>  (or re-run fetch.ps1
--      after adding it to the clone list there).
--   2. Update the four fields below to match the new plugin.
--   3. Set lualine to the matching theme name, or "auto".

return {
    -- The lazy.nvim plugin spec string: "owner/repo"
    -- The repo name must match a directory under vendor/plugins/
    plugin = "folke/tokyonight.nvim",

    -- The :colorscheme name passed to vim.cmd.colorscheme()
    name = "tokyonight",

    -- The Lua module name used in require(<module>).setup()
    module = "tokyonight",

    -- Options forwarded to require(module).setup()
    -- tokyonight styles: "night" | "storm" | "moon" | "day"
    opts = {
        style           = "night",
        transparent     = false,
        terminal_colors = true,
        styles = {
            comments  = { italic = true },
            keywords  = { italic = true },
            functions = {},
            variables = {},
        },
    },

    -- lualine theme — usually the same as `name`, or "auto"
    lualine = "tokyonight",
}
