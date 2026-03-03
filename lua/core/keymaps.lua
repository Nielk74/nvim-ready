vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- Escape
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

-- File operations
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit all" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Window resize
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Increase window height" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Decrease window height" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer navigation
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Line movement in normal and visual mode
map("n", "<A-j>", "<cmd>m .+1<cr>==",  { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==",  { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Indenting keeps selection
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Paste without overwriting register
map("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Diagnostics navigation
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>de", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Diagnostic list" })

-- Quickfix list
map("n", "<leader>co", "<cmd>copen<cr>",  { desc = "Open quickfix" })
map("n", "<leader>cc", "<cmd>cclose<cr>", { desc = "Close quickfix" })
map("n", "]c", "<cmd>cnext<cr>",          { desc = "Next quickfix" })
map("n", "[c", "<cmd>cprev<cr>",          { desc = "Previous quickfix" })

-- Splits
map("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>sh", "<cmd>split<cr>",  { desc = "Horizontal split" })
