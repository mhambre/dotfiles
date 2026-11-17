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
		local config_dir = vim.trim(vim.fn.system({ "lazygit", "-cd" }))
		local paths = vim.split(vim.env.LG_CONFIG_FILE or config_dir .. "/config.yml", ",", { trimempty = true })
		paths = vim.tbl_map(vim.fn.expand, paths)
		paths = vim.tbl_filter(function(path)
			return vim.fn.filereadable(path) == 1
		end, paths)
		table.insert(paths, vim.fn.stdpath("config") .. "/lazygit.yml")
		vim.g.lazygit_config_file_path = paths
		vim.g.lazygit_use_custom_config_file_path = 1

		local group = vim.api.nvim_create_augroup("LazyGitToggle", { clear = true })
		local git_win
		local editor_win

		local function hide()
			if git_win and vim.api.nvim_get_current_win() == git_win then
				vim.cmd.stopinsert()
				vim.api.nvim_win_set_config(git_win, { hide = true })
				if vim.api.nvim_win_is_valid(editor_win) then
					vim.api.nvim_set_current_win(editor_win)
				end
			end
		end

		vim.api.nvim_create_user_command("LazyGitHide", hide, {})
		vim.api.nvim_create_user_command("LazyGitToggle", function()
			if git_win and vim.api.nvim_win_is_valid(git_win) then
				if vim.api.nvim_get_current_win() == git_win then
					hide()
					return
				end
				editor_win = vim.api.nvim_get_current_win()
				vim.api.nvim_win_set_config(git_win, { hide = false })
				vim.api.nvim_set_current_win(git_win)
				vim.cmd.startinsert()
				return
			end
			vim.cmd.LazyGit()
		end, {})

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "lazygit",
			callback = function(event)
				git_win = vim.api.nvim_get_current_win()
				editor_win = vim.fn.win_getid(vim.fn.winnr("#"))
				vim.keymap.set({ "n", "t" }, "<leader>gg", hide, {
					buffer = event.buf,
					desc = "Hide LazyGit",
				})
			end,
		})
	end,
	keys = {
		{ "<leader>gg", "<cmd>LazyGitToggle<cr>", desc = "LazyGit" },
		{ "<leader>gf", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit current file" },
	},
}
