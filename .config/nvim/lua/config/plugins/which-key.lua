return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "modern",
		triggers = {},
		spec = {
			{ "<leader>a", group = "Agentic", mode = { "n", "v" } },
			{ "<leader>f", group = "Find", mode = { "n", "v" } },
			{ "<leader>g", group = "Git", mode = { "n", "v" } },
			{ "<leader>n", group = "Notes", mode = { "n", "v" } },
			{ "<leader>r", group = "Run Tools" },
			{ "<leader>t", group = "Trouble", mode = { "n", "v" } },
			{ "<leader>w", group = "Workspace" },
		},
	},
	keys = {
		{
			"<leader><leader>",
			function()
				require("which-key").show({ keys = "<leader>" })
			end,
			mode = { "n", "v" },
			desc = "Show leader keymaps",
		},
	},
}
