return {
	"retran/meow.review.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	event = "VeryLazy",
	config = function()
		require("meow.review").setup({})
	end,
	keys = {
		{ "<leader>na", "<Plug>(MeowReviewAdd)", mode = { "n", "v" }, desc = "Note add" },
		{ "<leader>ne", "<Plug>(MeowReviewEdit)", desc = "Note edit" },
		{ "<leader>nd", "<Plug>(MeowReviewDelete)", mode = { "n", "v" }, desc = "Note delete" },
		{ "<leader>nv", "<cmd>MeowReview view<cr>", desc = "Note view" },
		{ "<leader>nr", "<cmd>MeowReview resolve<cr>", desc = "Note resolve" },
		{ "<leader>ng", "<cmd>MeowReview goto<cr>", desc = "Note goto picker" },
		{ "<leader>nE", "<Plug>(MeowReviewExport)", desc = "Notes export" },
		{ "<leader>nX", "<Plug>(MeowReviewExportAndClear)", desc = "Notes export and clear" },
		{ "<leader>nc", "<Plug>(MeowReviewClear)", desc = "Notes clear all" },
		{ "]n", "<Plug>(MeowReviewNext)", desc = "Next note" },
		{ "[n", "<Plug>(MeowReviewPrev)", desc = "Previous note" },
	},
}
