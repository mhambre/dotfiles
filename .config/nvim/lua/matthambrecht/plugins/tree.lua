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
		local git_symbols = {
			added = "A", -- added to git
			modified = "M", -- modified in git
			deleted = "D", -- deleted in git
			renamed = "R", -- renamed in git
			untracked = "?", -- not tracked by git
			ignored = "I", -- ignored by git
			unstaged = "U", -- changed but not staged
			staged = "S", -- staged for commit
			conflict = "C", -- merge conflict
		}

		return {
			sources = { "filesystem", "buffers", "git_status" },

			enable_git_status = true,
			git_status = {
				symbols = git_symbols,
			},

			default_component_configs = {
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "",
					default = "",
				},
				git_status = {
					symbols = git_symbols,
				},
				modified = {
					symbol = "*",
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
				position = "right",
			},
			event_handlers = {
				{
					event = "neo_tree_buffer_enter",
					handler = function()
						vim.opt_local.number = true
						vim.opt_local.relativenumber = true
					end,
				},
			},
		}
	end,
}
