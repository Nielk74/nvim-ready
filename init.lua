-- Offline bootstrap: lazy.nvim is loaded from vendor/, never from the network.
-- Run fetch.ps1 on an internet-connected machine first to populate vendor/.
local lazypath = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "lazy.nvim")
if not vim.uv.fs_stat(lazypath) then
    vim.notify(
        "[custom-nvim] vendor/lazy.nvim not found.\n"
        .. "Run fetch.ps1 on a machine with internet access first.",
        vim.log.levels.ERROR
    )
    return
end
vim.opt.rtp:prepend(lazypath)

require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.themepicker")

local vendor_plugins = vim.fs.joinpath(vim.fn.stdpath("config"), "vendor", "plugins")

require("lazy").setup("plugins", {
    -- Point lazy at the local vendor/plugins/ directory.
    -- Every plugin whose spec uses a "owner/name" shorthand will be resolved
    -- to vendor/plugins/<name> instead of cloning from GitHub.
    dev = {
        path     = vendor_plugins,
        patterns = { "." },   -- match all plugins
        fallback = false,     -- never fall back to the network
    },

    -- Disable all network activity.
    checker          = { enabled = false },
    change_detection = { notify = false },
    install          = { missing = false },

    ui = {
        border = "rounded",
        -- No Nerd Font needed.
        icons = {
            cmd        = ">",
            config     = "C",
            event      = "E",
            ft         = "F",
            init       = "I",
            import     = "i",
            keys       = "K",
            lazy       = "z",
            loaded     = ".",
            not_loaded = "o",
            plugin     = "P",
            runtime    = "R",
            require    = "r",
            source     = "S",
            start      = "*",
            task       = "T",
            list       = { "-", "-", "-", "-" },
        },
    },

    performance = {
        rtp = {
            disabled_plugins = {
                "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
            },
        },
    },
})
