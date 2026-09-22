-- Keybinds
--- Plugin Keybinds
vim.keymap.set({ "n", "v" }, "<leader>ff", "<cmd>Telescope find_files hidden=true<CR>", { desc = "Find files" })
vim.keymap.set({ "n", "v" }, "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "Find text in workspace" })
vim.keymap.set({ "n", "v" }, "<leader>fd", "<cmd>Telescope lsp_definitions<CR>", { desc = "Find LSP definitions" })
vim.keymap.set({ "n", "v" }, "<leader>fg", "<cmd>Telescope git_status<CR>", { desc = "Find git changes" })
vim.keymap.set(
	{ "n", "v" },
	"<leader>fs",
	"<cmd>Telescope lsp_dynamic_workspace_symbols<CR>",
	{ desc = "Find workspace symbols" }
)
vim.keymap.set({ "n", "v" }, "<leader>b", "<cmd>Neotree toggle<CR>", { desc = "Browse files" })

--- Buffer Keybinds
vim.keymap.set({ "n", "v" }, "<A-h>", "<cmd>bprevious<CR>")
vim.keymap.set({ "n", "v" }, "<A-l>", "<cmd>bnext<CR>")
vim.keymap.set({ "n", "v" }, "<A-t>", "<cmd>enew<CR>")

--- Window Keybinds
vim.keymap.set({ "n", "v" }, "<A-w>", "<cmd>bdelete<CR>")
vim.keymap.set({ "n", "v" }, '<C-w>"', "<cmd>sp<CR>")
vim.keymap.set({ "n", "v" }, "<C-w>%", "<cmd>vsp<CR>")

--- General Keybinds
vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<cmd>w<CR>")

--- Paste without overwriting the default register
vim.keymap.set("x", "p", "P")

--- Debug helpers
local function copy_pos(mod, label)
	return function()
		local loc = vim.fn.expand("%" .. mod) .. ":" .. vim.fn.line(".")
		vim.fn.setreg("+", loc)
		vim.notify("Copied " .. label .. ": " .. loc)
	end
end

vim.keymap.set("n", "<leader>drn", copy_pos(":.", "relative"), { desc = "Copy relative file path and line number" })
vim.keymap.set("n", "<leader>dan", copy_pos(":p", "absolute"), { desc = "Copy absolute file path and line number" })
