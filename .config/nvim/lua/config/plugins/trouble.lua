return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = "Trouble",
	opts = {},
	keys = {
		{
			"<leader>tt",
			function()
				local trouble = require("trouble")
				trouble.toggle(trouble.last_mode or "diagnostics")
			end,
			desc = "Trouble toggle last pane",
		},
		{ "<leader>td", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble workspace diagnostics" },
		{ "<leader>tb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Trouble buffer diagnostics" },
		{ "<leader>ts", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Trouble symbols" },
		{ "<leader>tl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "Trouble LSP refs/defs" },
		{ "<leader>tq", "<cmd>Trouble qflist toggle<cr>", desc = "Trouble quickfix list" },
		{ "<leader>tL", "<cmd>Trouble loclist toggle<cr>", desc = "Trouble location list" },
	},
}
