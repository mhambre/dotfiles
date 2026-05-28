return {
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signcolumn = true,
			current_line_blame = true,
			current_line_blame_opts = {
				delay = 200,
				virt_text = true,
				virt_text_pos = "eol",
			},
			attach_to_untracked = true,
		},
	},
}
