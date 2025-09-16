return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	version = "*",
	opts = {
		options = {
			mode = "tabs",
			separator_style = "slope",
			show_buffer_close_icons = false,
			show_close_icon = false,
		},
		highlights = {
			-- overall bar behind tabs
			fill = {
				bg = "#1e1e1e", -- darker than term (#262626) so it stands out
			},

			-- inactive tabs
			background = {
				bg = "#262626",
				fg = "#c69752", -- soft sand (readable but subdued)
			},
			tab = {
				bg = "#262626",
				fg = "#c69752",
			},

			-- active tab
			tab_selected = {
				bg = "#2e2e2e",
				fg = "#ffcb83", -- main fg
				bold = true,
			},

			-- separator between tabs
			tab_separator = {
				fg = "#2e2e2e", -- match active tab edge
				bg = "#262626",
			},
			tab_separator_selected = {
				fg = "#2e2e2e",
				bg = "#2e2e2e",
			},

			-- indicators and icons
			indicator_selected = {
				fg = "#fc5e00", -- hot orange underline/triangle
				bg = "#2e2e2e",
			},
			buffer_selected = {
				fg = "#ffcb83",
				bg = "#2e2e2e",
				bold = true,
			},
			buffer_visible = {
				fg = "#c69752",
				bg = "#262626",
			},

			-- modified dots
			modified = {
				fg = "#c69752",
				bg = "#262626",
			},
			modified_visible = {
				fg = "#c69752",
				bg = "#262626",
			},
			modified_selected = {
				fg = "#f79500", -- warm amber for active modified
				bg = "#2e2e2e",
			},

			-- close buttons (muted)
			close_button = {
				fg = "#8c7458",
				bg = "#262626",
			},
			close_button_visible = {
				fg = "#8c7458",
				bg = "#262626",
			},
			close_button_selected = {
				fg = "#ff8c68", -- soft red/orange when active
				bg = "#2e2e2e",
			},

			-- separators for regular buffers (when not in 'tabs' mode, harmless here)
			separator = {
				fg = "#1e1e1e",
				bg = "#262626",
			},
			separator_visible = {
				fg = "#1e1e1e",
				bg = "#262626",
			},
			separator_selected = {
				fg = "#1e1e1e",
				bg = "#2e2e2e",
			},

			-- duplicates (dim them)
			duplicate = {
				fg = "#8c7458",
				bg = "#262626",
				italic = true,
			},
			duplicate_selected = {
				fg = "#d8c3a2",
				bg = "#2e2e2e",
				italic = true,
			},
			duplicate_visible = {
				fg = "#8c7458",
				bg = "#262626",
				italic = true,
			},
		},
	},
}
