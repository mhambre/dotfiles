-- Global Options
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
