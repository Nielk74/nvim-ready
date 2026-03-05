local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.splitbelow = true
opt.splitright = true
opt.laststatus = 3          -- single global statusline
opt.showmode = false        -- lualine shows the mode
opt.cmdheight = 1

-- Editing
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- System
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.updatetime = 200
opt.timeoutlen = 300
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

-- Completion
opt.completeopt = { "menuone", "noselect" }
opt.pumheight = 10

-- Windows shell
if vim.fn.has("win32") == 1 then
    -- Use PowerShell for shell commands
    opt.shell = "powershell"
    opt.shellcmdflag = "-NoLogo -NonInteractive -Command"
    opt.shellxquote = ""
    opt.shellquote = ""
    opt.shellpipe = "| Out-File -Encoding UTF8 %s"
    opt.shellredir = "| Out-File -Encoding UTF8 %s"
end
