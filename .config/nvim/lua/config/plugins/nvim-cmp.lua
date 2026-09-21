return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		{
			"L3MON4D3/LuaSnip",
			-- follow latest release.
			version = "v2.*",
			-- install jsregexp (optional!).
			build = "make install_jsregexp",
		},
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- vs-code like pictograms
	},
	config = function()
		local cmp = require("cmp")

		local luasnip = require("luasnip")

		local lspkind = require("lspkind")

		-- loads vscode style snippets from installed plugins (e.g. friendly-snippets)
		require("luasnip.loaders.from_vscode").lazy_load()

		-- rank private/dunder members below public ones
		local function under_compare(entry1, entry2)
			local _, under1 = entry1.completion_item.label:find("^_+")
			local _, under2 = entry2.completion_item.label:find("^_+")
			under1 = under1 or 0
			under2 = under2 or 0
			if under1 ~= under2 then
				return under1 < under2
			end
		end

		cmp.setup({
			completion = {
				completeopt = "menu,menuone,noinsert",
			},
			preselect = cmp.PreselectMode.Item,
			snippet = { -- configure how nvim-cmp interacts with snippet engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
				["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
				["<C-e>"] = cmp.mapping.abort(), -- close completion window
				["<CR>"] = cmp.mapping.confirm({ select = false }),
			}),
			-- sources for autocompletion
			-- buffer/path live in a fallback group so plain buffer words
			-- only show up when the LSP has nothing to offer
			sources = cmp.config.sources({
				{
					name = "nvim_lsp",
					entry_filter = function(entry)
						-- plain word suggestions from the server add noise
						return entry:get_kind() ~= cmp.lsp.CompletionItemKind.Text
					end,
				},
				{ name = "luasnip" }, -- snippets
			}, {
				{ name = "buffer", keyword_length = 3, max_item_count = 5 },
				{ name = "path" }, -- file system paths
			}),

			sorting = {
				comparators = {
					cmp.config.compare.offset,
					cmp.config.compare.exact,
					cmp.config.compare.score,
					cmp.config.compare.sort_text,
					under_compare,
					cmp.config.compare.recently_used,
					cmp.config.compare.locality,
					cmp.config.compare.kind,
					cmp.config.compare.length,
					cmp.config.compare.order,
				},
			},

			-- configure lspkind for vs-code like pictograms in completion menu
			formatting = {
				format = lspkind.cmp_format({
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
		})

		-- cmp only auto-triggers on typed chars, so reopen the menu after
		-- deletions when the cursor still sits at the end of a word
		vim.api.nvim_create_autocmd("TextChangedI", {
			group = vim.api.nvim_create_augroup("CmpCompleteOnDelete", {}),
			callback = function()
				if cmp.visible() then
					return
				end
				local col = vim.api.nvim_win_get_cursor(0)[2]
				local char_before = vim.api.nvim_get_current_line():sub(col, col)
				if char_before:match("[%w_]") then
					cmp.complete({ reason = cmp.ContextReason.Auto })
				end
			end,
		})
	end,
}
