return {
	{
		"rest-nvim/rest.nvim",
		ft = "http",
		cmd = "Rest",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		keys = {
			{ "<leader>rh", "<cmd>botright vertical Rest run<CR>", desc = "Run HTTP request" },
		},
	},
}
