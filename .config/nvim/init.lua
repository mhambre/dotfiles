------------------------------
---- NeoVim Configuration ----
------------------------------

-- Global Variables
--- Theme
vim.opt.termguicolors = true
vim.cmd [[
  hi Normal ctermbg=none guibg=none
  hi NormalNC ctermbg=none guibg=none
  hi SignColumn ctermbg=none guibg=none
  hi EndOfBuffer ctermbg=none guibg=none
]]

--- Line Numbers
vim.wo.number = true
vim.wo.relativenumber = true

--- Spacing
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Plugins
vim.opt.rtp:prepend("~/.config/nvim/lazy/lazy.nvim")

require("lazy").setup("plugins")

-- Keybinds
vim.keymap.set({ "n", "v" }, "<A-f>", "<cmd>Telescope find_files<CR>")
vim.keymap.set({ "n", "v" }, "<A-b>", "<cmd>Neotree<CR>")
vim.keymap.set({ "n", "v" }, "<A-g>", "<cmd>LazyGit<CR>")

