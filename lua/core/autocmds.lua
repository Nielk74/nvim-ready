local function augroup(name)
    return vim.api.nvim_create_augroup("nvim_" .. name, { clear = true })
end

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
    end,
})

-- Strip trailing whitespace on save (skip binary and special filetypes)
vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("trim_whitespace"),
    pattern = "*",
    callback = function()
        if not vim.bo.modifiable or vim.bo.readonly then return end
        local ft = vim.bo.filetype
        local skip = { "markdown", "diff", "gitcommit" }
        for _, s in ipairs(skip) do
            if ft == s then return end
        end
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[%s/\s\+$//e]])
        vim.api.nvim_win_set_cursor(0, pos)
    end,
})

-- 2-space indent for web and config filetypes
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("two_space_indent"),
    pattern = { "lua", "javascript", "typescript", "typescriptreact",
                "javascriptreact", "json", "jsonc", "yaml", "html", "css",
                "scss", "xml" },
    callback = function()
        vim.opt_local.tabstop    = 2
        vim.opt_local.shiftwidth = 2
    end,
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = { "help", "man", "lspinfo", "checkhealth", "qf" },
    callback = function(event)
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
    end,
})

-- Resize splits when the terminal window is resized
vim.api.nvim_create_autocmd("VimResized", {
    group = augroup("resize_splits"),
    callback = function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end,
})

-- Restore cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("restore_cursor"),
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local line_count = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= line_count then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
