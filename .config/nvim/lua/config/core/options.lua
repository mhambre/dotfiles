-- Global Options
--- EditorConfig
vim.g.editorconfig = true

--- Theme
vim.opt.termguicolors = true
vim.cmd.colorscheme("theme")

--- Line Numbers
vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.signcolumn = "yes:2"

--- Spacing
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

--- Clipboard
vim.opt.clipboard = ""
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		if vim.v.event.operator == "y" then
			vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
		end
	end,
})

--- Editor Lines
vim.opt.colorcolumn = "80,120"
