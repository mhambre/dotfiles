return {
	{
		"rest-nvim/rest.nvim",
		ft = "http",
		cmd = "Rest",
		build = false,
		dependencies = {
			"j-hui/fidget.nvim",
			"nvim-neotest/nvim-nio",
			"nvim-treesitter/nvim-treesitter",
			{
				"lunarmodules/lua-mimetypes",
				build = false,
				config = function(plugin)
					package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
				end,
			},
			{
				"manoelcampos/xml2lua",
				build = false,
				config = function(plugin)
					package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
				end,
			},
		},
		keys = {
			{ "<leader>rh", "<cmd>botright vertical Rest run<CR>", desc = "Run HTTP request" },
		},
	},
}
