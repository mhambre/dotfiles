return {
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "-" },
				topdelete = { text = "^" },
				changedelete = { text = "!" },
				untracked = { text = "?" },
			},
			signs_staged = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "-" },
				topdelete = { text = "^" },
				changedelete = { text = "!" },
				untracked = { text = "?" },
			},
			signcolumn = true,
			current_line_blame = true,
			current_line_blame_opts = {
				delay = 200,
				virt_text = true,
				virt_text_pos = "eol",
			},
			attach_to_untracked = true,
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")

				local function map(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
				end

				map("n", "<leader>gn", function()
					gitsigns.nav_hunk("next")
				end, "Git next hunk")
				map("n", "<leader>gN", function()
					gitsigns.nav_hunk("prev")
				end, "Git previous hunk")
				map("n", "<leader>gp", gitsigns.preview_hunk, "Git preview hunk")
				map("n", "<leader>gi", gitsigns.preview_hunk_inline, "Git preview hunk inline")
				map("n", "<leader>gs", gitsigns.stage_hunk, "Git stage hunk")
				map("n", "<leader>gr", gitsigns.reset_hunk, "Git reset hunk")
				map("v", "<leader>gs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Git stage selection")
				map("v", "<leader>gr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Git reset selection")
				map("n", "<leader>gS", gitsigns.stage_buffer, "Git stage buffer")
				map("n", "<leader>gR", gitsigns.reset_buffer, "Git reset buffer")
				map("n", "<leader>gu", gitsigns.undo_stage_hunk, "Git undo stage hunk")
				map("n", "<leader>gb", function()
					gitsigns.blame_line({ full = true })
				end, "Git blame line")
				map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "Git toggle line blame")
				map("n", "<leader>gd", gitsigns.diffthis, "Git diff file")
				map("n", "<leader>gD", function()
					gitsigns.diffthis("~")
				end, "Git diff file against previous commit")
				map("n", "<leader>gq", function()
					gitsigns.setqflist("all")
				end, "Git hunks quickfix")
				map("n", "<leader>gt", gitsigns.toggle_deleted, "Git toggle deleted lines")
			end,
		},
	},
}
