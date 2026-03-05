-- Shared lualine configuration.
-- Used by lua/plugins/ui.lua (initial setup) and lua/core/themepicker.lua
-- (live theme updates) so the sections are never duplicated.

local M = {}

M.sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 1 } },
    lualine_x = {
        { "lsp_client_names", fmt = function(names) return names ~= "" and names or "no LSP" end },
        "encoding",
        "fileformat",
        "filetype",
    },
    lualine_y = { "progress" },
    lualine_z = { "location" },
}

M.inactive_sections = {
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "location" },
}

M.options_base = {
    globalstatus            = true,
    component_separators    = { left = "|", right = "|" },
    section_separators      = { left = "",  right = ""  },
}

-- Call this to (re)apply lualine with a given theme string.
function M.setup(lualine_theme)
    require("lualine").setup({
        options           = vim.tbl_extend("force", M.options_base, { theme = lualine_theme }),
        sections          = M.sections,
        inactive_sections = M.inactive_sections,
    })
end

return M
