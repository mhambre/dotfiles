return {
	{
		"terrortylor/nvim-comment",
		keys = {
			{ "<C-_>", mode = "n", desc = "Toggle comment line" },
			{ "<C-_>", mode = "x", desc = "Toggle comment selection" },
		},
		config = function()
			require("nvim_comment").setup({ create_mappings = false }) -- we'll define our own
			local map, opts = vim.keymap.set, { silent = true, noremap = true }
			-- Normal mode: toggle current line
			map("n", "<C-_>", "<cmd>CommentToggle<CR>", opts)
			-- Visual mode: toggle selection
			map("x", "<C-_>", ":'<,'>CommentToggle<CR>", opts)
		end,
	},
}
