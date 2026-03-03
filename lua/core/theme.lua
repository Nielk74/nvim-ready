-- ============================================================
-- Theme configuration — edit this file to change the theme.
-- Restart Neovim after saving.
-- All themes below are pre-vendored and work fully offline.
-- ============================================================
--
-- Copy any block below and replace the `return { ... }` at the bottom.
--
-- ── tokyonight ────────────────────────────────────────────────
--   plugin  = "folke/tokyonight.nvim"
--   name    = "tokyonight"
--   module  = "tokyonight"
--   opts    = { style = "night" }   -- "night" | "storm" | "moon" | "day"
--   lualine = "tokyonight"
--
-- ── catppuccin ────────────────────────────────────────────────
--   plugin    = "catppuccin/nvim"
--   lazy_name = "catppuccin"        -- repo is "nvim"; this sets the local dir name
--   name      = "catppuccin-mocha"  -- "catppuccin-latte" | "catppuccin-frappe"
--                                   -- "catppuccin-macchiato" | "catppuccin-mocha"
--   module    = "catppuccin"
--   opts      = { flavour = "mocha" }
--   lualine   = "catppuccin"
--
-- ── kanagawa ──────────────────────────────────────────────────
--   plugin  = "rebelot/kanagawa.nvim"
--   name    = "kanagawa"            -- "kanagawa" | "kanagawa-wave" | "kanagawa-dragon"
--                                   -- "kanagawa-lotus"
--   module  = "kanagawa"
--   opts    = { theme = "wave" }    -- "wave" | "dragon" | "lotus"
--   lualine = "kanagawa"
--
-- ── rose-pine ─────────────────────────────────────────────────
--   plugin    = "rose-pine/neovim"
--   lazy_name = "rose-pine"         -- repo is "neovim"; this sets the local dir name
--   name      = "rose-pine"         -- "rose-pine" | "rose-pine-main" | "rose-pine-moon"
--                                   -- "rose-pine-dawn"
--   module    = "rose-pine"
--   opts      = { variant = "main" } -- "auto" | "main" | "moon" | "dawn"
--   lualine   = "rose-pine"
--
-- ── nightfox ──────────────────────────────────────────────────
--   plugin  = "EdenEast/nightfox.nvim"
--   name    = "nightfox"            -- "nightfox" | "dayfox" | "dawnfox" | "duskfox"
--                                   -- "nordfox" | "carbonfox" | "terafox"
--   module  = "nightfox"
--   opts    = {}
--   lualine = "nightfox"            -- use the same value as name
--
-- ── gruvbox ───────────────────────────────────────────────────
--   plugin  = "ellisonleao/gruvbox.nvim"
--   name    = "gruvbox"
--   module  = "gruvbox"
--   opts    = { contrast = "hard" } -- "" | "soft" | "hard"
--   lualine = "gruvbox"
--
-- ── onedark ───────────────────────────────────────────────────
--   plugin  = "navarasu/onedark.nvim"
--   name    = "onedark"
--   module  = "onedark"
--   opts    = { style = "dark" }    -- "dark" | "darker" | "cool" | "deep"
--                                   -- "warm" | "warmer" | "light"
--   lualine = "onedark"
--
-- ============================================================

return {
    plugin  = "folke/tokyonight.nvim",
    name    = "tokyonight",
    module  = "tokyonight",
    opts    = {
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
    lualine = "tokyonight",
}
