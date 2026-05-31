-- Global Options
--- EditorConfig
vim.g.editorconfig = true

--- Theme
vim.opt.termguicolors = true
vim.cmd.colorscheme("theme")

--- Line Numbers
vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.signcolumn = "yes"

--- Spacing
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

--- Clipboard
vim.opt.clipboard = "unnamedplus"

--- Editor Lines
vim.opt.colorcolumn = "80,120"
