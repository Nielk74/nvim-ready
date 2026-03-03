-- Shared lualine configuration.
-- Used by lua/plugins/ui.lua (initial setup) and lua/core/themepicker.lua
-- (live theme updates) so the sections are never duplicated.

local M = {}

local function lsp_name()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then return "no LSP" end
    local names = {}
    for _, c in ipairs(clients) do
        table.insert(names, c.name)
    end
    return table.concat(names, ", ")
end

M.sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { lsp_name, "encoding", "fileformat", "filetype" },
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
