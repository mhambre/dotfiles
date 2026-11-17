local function review_store_path()
	local dir = vim.fn.expand("%:p:h")
	if dir == "" then
		dir = vim.fn.getcwd()
	end

	local result = vim.system({ "git", "-C", dir, "rev-parse", "--absolute-git-dir" }, { text = true }):wait()
	if result.code == 0 and result.stdout ~= "" then
		return vim.fs.joinpath(vim.trim(result.stdout), "meow-review", "annotations.json")
	end

	return ".cache/meow-review/annotations.json"
end

return {
	"retran/meow.review.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	event = "VeryLazy",
	config = function()
		require("meow.review").setup({
			store_path = review_store_path(),
			auto_gitignore = false,
			annotation_types = {
				ISSUE = { icon = "\u{f188}" },
				SUGGESTION = { icon = "\u{f0eb}" },
				NOTE = { icon = "\u{f075}" },
			},
		})
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
