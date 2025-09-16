return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	lazy = false,
	opts = function()
		local use_nerd = true

		local nerd = {
			added = "", -- nf-fa-plus
			modified = "", -- nf-oct-dot_fill
			deleted = "", -- nf-oct-diff_removed
			renamed = "", -- nf-oct-diff_renamed
			untracked = "", -- nf-fa-question
			ignored = "", -- nf-cod-eye_closed (or "")
			unstaged = "", -- nf-fa-dot_circle_o
			staged = "", -- nf-fa-check_circle
			conflict = "", -- nf-dev-git_compare
		}

		local ascii = {
			added = "+",
			modified = "~",
			deleted = "-",
			renamed = "→",
			untracked = "?",
			ignored = "!",
			unstaged = "•",
			staged = "✓",
			conflict = "×",
		}

		return {
			sources = { "filesystem", "buffers", "git_status" },

			enable_git_status = true,
			git_status = {
				symbols = use_nerd and nerd or ascii,
			},

			default_component_configs = {
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "",
					default = "",
				},
				git_status = {
					symbols = use_nerd and nerd or ascii,
				},
				modified = {
					symbol = use_nerd and "●" or "*",
				},
			},

			-- ensure the git status component is shown in nodes
			renderers = {
				directory = {
					{ "indent" },
					{ "icon" },
					{ "current_filter" },
					{ "name" },
					{ "diagnostics" },
					{ "clipboard" },
					{ "git_status" },
				},
				file = {
					{ "indent" },
					{ "icon" },
					{ "name", use_git_status_colors = true },
					{ "diagnostics" },
					{ "git_status" },
					{ "clipboard" },
				},
			},

			filesystem = {
				filtered_items = {
					visible = true,
				},
				use_libuv_file_watcher = true,
			},
			window = {
				width = 32,
			},
		}
	end,
}
