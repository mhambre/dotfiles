return {
	"kdheepak/lazygit.nvim",
	lazy = true,
	cmd = {
		"LazyGit",
		"LazyGitConfig",
		"LazyGitCurrentFile",
		"LazyGitFilter",
		"LazyGitFilterCurrentFile",
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		local group = vim.api.nvim_create_augroup("LazyGitToggle", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "lazygit",
			callback = function(event)
				vim.keymap.set("t", "<leader>gg", function()
					vim.api.nvim_win_close(0, true)
				end, {
					buffer = event.buf,
					desc = "Hide LazyGit",
				})
			end,
		})
	end,
	keys = {
		{ "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
		{ "<leader>gf", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit current file" },
	},
}
