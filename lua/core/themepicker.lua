-- Theme picker — :ThemeSwitch / <leader>ft
-- Applies a theme live (no restart needed) and saves lua/core/theme.lua
-- for persistence across sessions.

local M = {}

-- vendor_dir is the exact directory name under vendor/plugins/ as cloned by fetch.ps1.
-- All other fields match the schema of lua/core/theme.lua.
local presets = {
    -- tokyonight
    { label = "tokyonight · night",        vendor_dir = "tokyonight.nvim",  plugin = "folke/tokyonight.nvim",    name = "tokyonight",           module = "tokyonight",  opts = { style = "night"   }, lualine = "tokyonight" },
    { label = "tokyonight · storm",        vendor_dir = "tokyonight.nvim",  plugin = "folke/tokyonight.nvim",    name = "tokyonight",           module = "tokyonight",  opts = { style = "storm"   }, lualine = "tokyonight" },
    { label = "tokyonight · moon",         vendor_dir = "tokyonight.nvim",  plugin = "folke/tokyonight.nvim",    name = "tokyonight",           module = "tokyonight",  opts = { style = "moon"    }, lualine = "tokyonight" },
    { label = "tokyonight · day",          vendor_dir = "tokyonight.nvim",  plugin = "folke/tokyonight.nvim",    name = "tokyonight",           module = "tokyonight",  opts = { style = "day"     }, lualine = "tokyonight" },
    -- catppuccin
    { label = "catppuccin · latte",        vendor_dir = "catppuccin",       plugin = "catppuccin/nvim",          name = "catppuccin-latte",     module = "catppuccin",  opts = { flavour = "latte"     }, lualine = "catppuccin", lazy_name = "catppuccin" },
    { label = "catppuccin · frappe",       vendor_dir = "catppuccin",       plugin = "catppuccin/nvim",          name = "catppuccin-frappe",    module = "catppuccin",  opts = { flavour = "frappe"    }, lualine = "catppuccin", lazy_name = "catppuccin" },
    { label = "catppuccin · macchiato",    vendor_dir = "catppuccin",       plugin = "catppuccin/nvim",          name = "catppuccin-macchiato", module = "catppuccin",  opts = { flavour = "macchiato" }, lualine = "catppuccin", lazy_name = "catppuccin" },
    { label = "catppuccin · mocha",        vendor_dir = "catppuccin",       plugin = "catppuccin/nvim",          name = "catppuccin-mocha",     module = "catppuccin",  opts = { flavour = "mocha"     }, lualine = "catppuccin", lazy_name = "catppuccin" },
    -- kanagawa
    { label = "kanagawa · wave",           vendor_dir = "kanagawa.nvim",    plugin = "rebelot/kanagawa.nvim",    name = "kanagawa-wave",        module = "kanagawa",    opts = { theme = "wave"   }, lualine = "kanagawa" },
    { label = "kanagawa · dragon",         vendor_dir = "kanagawa.nvim",    plugin = "rebelot/kanagawa.nvim",    name = "kanagawa-dragon",      module = "kanagawa",    opts = { theme = "dragon" }, lualine = "kanagawa" },
    { label = "kanagawa · lotus",          vendor_dir = "kanagawa.nvim",    plugin = "rebelot/kanagawa.nvim",    name = "kanagawa-lotus",       module = "kanagawa",    opts = { theme = "lotus"  }, lualine = "kanagawa" },
    -- rose-pine
    { label = "rose-pine · main",          vendor_dir = "rose-pine",        plugin = "rose-pine/neovim",         name = "rose-pine",            module = "rose-pine",   opts = { variant = "main"  }, lualine = "rose-pine", lazy_name = "rose-pine" },
    { label = "rose-pine · moon",          vendor_dir = "rose-pine",        plugin = "rose-pine/neovim",         name = "rose-pine-moon",       module = "rose-pine",   opts = { variant = "moon"  }, lualine = "rose-pine", lazy_name = "rose-pine" },
    { label = "rose-pine · dawn",          vendor_dir = "rose-pine",        plugin = "rose-pine/neovim",         name = "rose-pine-dawn",       module = "rose-pine",   opts = { variant = "dawn"  }, lualine = "rose-pine", lazy_name = "rose-pine" },
    -- nightfox
    { label = "nightfox",                  vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "nightfox",             module = "nightfox",    opts = {}, lualine = "nightfox"   },
    { label = "dayfox",                    vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "dayfox",               module = "nightfox",    opts = {}, lualine = "dayfox"     },
    { label = "dawnfox",                   vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "dawnfox",              module = "nightfox",    opts = {}, lualine = "dawnfox"    },
    { label = "duskfox",                   vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "duskfox",              module = "nightfox",    opts = {}, lualine = "duskfox"    },
    { label = "nordfox",                   vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "nordfox",              module = "nightfox",    opts = {}, lualine = "nordfox"    },
    { label = "carbonfox",                 vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "carbonfox",            module = "nightfox",    opts = {}, lualine = "carbonfox"  },
    { label = "terafox",                   vendor_dir = "nightfox.nvim",    plugin = "EdenEast/nightfox.nvim",   name = "terafox",              module = "nightfox",    opts = {}, lualine = "terafox"    },
    -- gruvbox
    { label = "gruvbox · medium",          vendor_dir = "gruvbox.nvim",     plugin = "ellisonleao/gruvbox.nvim", name = "gruvbox",              module = "gruvbox",     opts = { contrast = ""     }, lualine = "gruvbox" },
    { label = "gruvbox · soft",            vendor_dir = "gruvbox.nvim",     plugin = "ellisonleao/gruvbox.nvim", name = "gruvbox",              module = "gruvbox",     opts = { contrast = "soft" }, lualine = "gruvbox" },
    { label = "gruvbox · hard",            vendor_dir = "gruvbox.nvim",     plugin = "ellisonleao/gruvbox.nvim", name = "gruvbox",              module = "gruvbox",     opts = { contrast = "hard" }, lualine = "gruvbox" },
    -- onedark
    { label = "onedark · dark",            vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "dark"    }, lualine = "onedark" },
    { label = "onedark · darker",          vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "darker"  }, lualine = "onedark" },
    { label = "onedark · cool",            vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "cool"    }, lualine = "onedark" },
    { label = "onedark · deep",            vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "deep"    }, lualine = "onedark" },
    { label = "onedark · warm",            vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "warm"    }, lualine = "onedark" },
    { label = "onedark · warmer",          vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "warmer"  }, lualine = "onedark" },
    { label = "onedark · light",           vendor_dir = "onedark.nvim",     plugin = "navarasu/onedark.nvim",    name = "onedark",              module = "onedark",     opts = { style = "light"   }, lualine = "onedark" },
}

-- Prepend a vendor plugin dir to rtp (no-op if already present).
local function rtp_add(dir)
    for _, p in ipairs(vim.opt.rtp:get()) do
        if p == dir then return end
    end
    vim.opt.rtp:prepend(dir)
end

-- Apply a preset live without restarting.
local function apply(preset)
    local vendor = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "plugins")
    rtp_add(vim.fs.joinpath(vendor, preset.vendor_dir))

    local ok, err = pcall(function()
        require(preset.module).setup(preset.opts)
        vim.cmd.colorscheme(preset.name)
    end)
    if not ok then
        vim.notify("[ThemeSwitch] failed to apply '" .. preset.label .. "':\n" .. err, vim.log.levels.ERROR)
        return false
    end

    -- Update lualine if loaded.
    local ll_ok, lualine_cfg = pcall(require, "core.lualine_config")
    if ll_ok then
        pcall(lualine_cfg.setup, preset.lualine)
    end

    return true
end

-- Serialize a preset back into theme.lua content.
local function to_theme_lua(preset)
    local lines = {
        "-- Theme set by :ThemeSwitch",
        "-- Edit manually for advanced options (see README for full recipes).",
        "return {",
        string.format('    plugin  = "%s",', preset.plugin),
    }
    if preset.lazy_name then
        lines[#lines + 1] = string.format('    lazy_name = "%s",', preset.lazy_name)
    end
    lines[#lines + 1] = string.format('    name    = "%s",', preset.name)
    lines[#lines + 1] = string.format('    module  = "%s",', preset.module)

    local opt_parts = {}
    for k, v in pairs(preset.opts) do
        if type(v) == "string" then
            opt_parts[#opt_parts + 1] = string.format('%s = "%s"', k, v)
        elseif type(v) == "boolean" then
            opt_parts[#opt_parts + 1] = string.format("%s = %s", k, tostring(v))
        end
    end
    lines[#lines + 1] = "    opts    = { " .. table.concat(opt_parts, ", ") .. " },"
    lines[#lines + 1] = string.format('    lualine = "%s",', preset.lualine)
    lines[#lines + 1] = "}"
    return lines
end

-- Persist the selected preset to lua/core/theme.lua.
local function save(preset)
    local path = vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "core", "theme.lua")
    local ok, err = pcall(vim.fn.writefile, to_theme_lua(preset), path)
    if not ok then
        vim.notify("[ThemeSwitch] could not save theme.lua:\n" .. err, vim.log.levels.WARN)
    end
end

-- Open the picker.
function M.pick()
    local labels = {}
    for _, p in ipairs(presets) do
        labels[#labels + 1] = p.label
    end

    vim.ui.select(labels, { prompt = "Theme" }, function(choice)
        if not choice then return end
        for _, p in ipairs(presets) do
            if p.label == choice then
                if apply(p) then
                    save(p)
                    vim.notify("Theme: " .. p.label, vim.log.levels.INFO)
                end
                return
            end
        end
    end)
end

vim.api.nvim_create_user_command("ThemeSwitch", M.pick, { desc = "Switch colorscheme" })
vim.keymap.set("n", "<leader>ft", M.pick, { desc = "Switch theme" })

return M
