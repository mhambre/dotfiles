local p = {
	name = "ic_orange_ppl",
	bg = "#262626",
	fg = "#ffcb83",
	cursor = "#fc531d",

	-- ANSI (0–15) from Tabby palette
	c0 = "#000000",
	c1 = "#c13900",
	c2 = "#a4a900",
	c3 = "#caaf00",
	c4 = "#bd6d00",
	c5 = "#fc5e00",
	c6 = "#f79500",
	c7 = "#ffc88a",
	c8 = "#6a4f2a",
	c9 = "#ff8c68",
	c10 = "#f6ff40",
	c11 = "#ffe36e",
	c12 = "#ffbe55",
	c13 = "#fc874f",
	c14 = "#c69752",
	c15 = "#fafaff",
}

local function hl(group, opts)
	vim.api.nvim_set_hl(0, group, opts)
end

-- announce
vim.g.colors_name = p.name

-- terminal colors (so :terminal matches)
for i = 0, 15 do
	vim.g["terminal_color_" .. i] = p["c" .. i]
end

-- basic ui
hl("Normal", { fg = p.fg, bg = p.bg })
hl("NormalNC", { fg = p.fg, bg = p.bg })
hl("Cursor", { fg = p.bg, bg = p.cursor })
hl("CursorLine", { bg = "#2e2e2e" })
hl("CursorColumn", { bg = "#2e2e2e" })
hl("ColorColumn", { bg = "#2b2b2b" })
hl("Visual", { bg = "#3a2b22" }) -- warm, low-contrast selection
hl("Search", { bg = p.c4, fg = p.bg }) -- dark amber
hl("IncSearch", { bg = p.c5, fg = p.bg }) -- hot orange
hl("LineNr", { fg = "#665847" })
hl("CursorLineNr", { fg = p.c12, bold = true })
hl("VertSplit", { fg = "#3a3a3a" })
hl("WinSeparator", { fg = "#3a3a3a" })
hl("SignColumn", { bg = p.bg })
hl("Pmenu", { fg = p.fg, bg = "#2b2b2b" })
hl("PmenuSel", { fg = p.bg, bg = p.c13, bold = true })
hl("PmenuSbar", { bg = "#2f2f2f" })
hl("PmenuThumb", { bg = "#444444" })
hl("StatusLine", { fg = p.bg, bg = p.c12, bold = true })
hl("StatusLineNC", { fg = "#cdb89c", bg = "#2f2f2f" })
hl("TabLine", { fg = "#cdb89c", bg = "#2a2a2a" })
hl("TabLineSel", { fg = p.bg, bg = p.c6, bold = true })
hl("TabLineFill", { bg = "#252525" })
hl("MatchParen", { fg = p.c15, bg = "#3b2a1f", bold = true })
hl("Whitespace", { fg = "#3a332b" })

-- syntax (base Vim groups)
hl("Comment", { fg = p.c14, italic = true }) -- soft sand
hl("Constant", { fg = p.c11 })
hl("String", { fg = p.c12 })
hl("Character", { fg = p.c12 })
hl("Number", { fg = p.c10 })
hl("Boolean", { fg = p.c10, bold = true })
hl("Float", { fg = p.c10 })

hl("Identifier", { fg = p.c7 })
hl("Function", { fg = p.c13, bold = true })

hl("Statement", { fg = p.c6 })
hl("Conditional", { fg = p.c6, bold = true })
hl("Repeat", { fg = p.c6 })
hl("Label", { fg = p.c5 })
hl("Operator", { fg = p.c11 })
hl("Keyword", { fg = p.c5, italic = true })
hl("Exception", { fg = p.c9 })

hl("PreProc", { fg = p.c3 })
hl("Include", { fg = p.c3 })
hl("Define", { fg = p.c3 })
hl("Macro", { fg = p.c3 })
hl("PreCondit", { fg = p.c3 })

hl("Type", { fg = p.c7 })
hl("StorageClass", { fg = p.c7 })
hl("Structure", { fg = p.c7 })
hl("Typedef", { fg = p.c7 })

hl("Special", { fg = p.c12 })
hl("SpecialChar", { fg = p.c12 })
hl("Tag", { fg = p.c6 })
hl("Delimiter", { fg = "#cfae86" })
hl("SpecialComment", { fg = p.c14, italic = true })
hl("Debug", { fg = p.c9 })

hl("Underlined", { underline = true })
hl("Bold", { bold = true })
hl("Italic", { italic = true })
hl("Todo", { fg = p.bg, bg = p.c6, bold = true })

-- diagnostics (LSP)
hl("Error", { fg = p.c9 })
hl("WarningMsg", { fg = p.c11 })
hl("MoreMsg", { fg = p.c6 })
hl("Question", { fg = p.c6 })

hl("DiagnosticError", { fg = p.c9 })
hl("DiagnosticWarn", { fg = p.c11 })
hl("DiagnosticInfo", { fg = p.c12 })
hl("DiagnosticHint", { fg = p.c14 })
hl("DiagnosticOk", { fg = p.c6 })

hl("DiagnosticUnderlineError", { undercurl = true, sp = p.c9 })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = p.c11 })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = p.c12 })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = p.c14 })

-- diffs & git
hl("DiffAdd", { bg = "#243018", fg = "#e6ffb0" })
hl("DiffChange", { bg = "#2b2620" })
hl("DiffDelete", { bg = "#311a12", fg = p.c9 })
hl("DiffText", { bg = "#3a2f25", bold = true })

hl("GitSignsAdd", { fg = p.c10 })
hl("GitSignsChange", { fg = p.c12 })
hl("GitSignsDelete", { fg = p.c9 })

-- Treesitter links (keep lean; link to base groups)
local links = {
	["@comment"] = "Comment",
	["@string"] = "String",
	["@character"] = "Character",
	["@number"] = "Number",
	["@boolean"] = "Boolean",
	["@float"] = "Float",
	["@constant"] = "Constant",
	["@constant.builtin"] = "Constant",
	["@variable"] = "Identifier",
	["@variable.builtin"] = "Identifier",
	["@function"] = "Function",
	["@function.builtin"] = "Function",
	["@method"] = "Function",
	["@field"] = "Identifier",
	["@property"] = "Identifier",
	["@keyword"] = "Keyword",
	["@keyword.function"] = "Keyword",
	["@conditional"] = "Conditional",
	["@repeat"] = "Repeat",
	["@operator"] = "Operator",
	["@type"] = "Type",
	["@type.builtin"] = "Type",
	["@namespace"] = "Identifier",
	["@tag"] = "Tag",
	["@punctuation.delimiter"] = "Delimiter",
	["@punctuation.bracket"] = "Delimiter",
}
for from, to in pairs(links) do
	hl(from, { link = to })
end

-- Neovim 0.9+ builtins
hl("WinBar", { fg = "#d8c3a2", bg = "#2b2b2b" })
hl("WinBarNC", { fg = "#a9906f", bg = "#2a2a2a" })
hl("Folded", { fg = "#bfa37f", bg = "#2a2723", italic = true })
hl("FoldColumn", { fg = "#8c7458", bg = p.bg })

-- Optional: subtle rainbow-ish bracket colors (re-using palette)
for i, col in ipairs({ p.c14, p.c7, p.c12, p.c11, p.c6, p.c5 }) do
	hl("RainbowDelimiter" .. i, { fg = col })
end
