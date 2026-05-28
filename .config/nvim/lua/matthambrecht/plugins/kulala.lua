return {
	{
		"mistweaverco/kulala.nvim",
		ft = "http",
		opts = {},
		init = function()
			vim.fn.mkdir(vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser"), "p")
		end,
		keys = {
			{ "<leader>rh", "<cmd>lua require('kulala').run()<CR>", desc = "Run HTTP request" },
		},
	},
}
