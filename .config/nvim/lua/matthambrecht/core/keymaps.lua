-- Keybinds
--- Plugin Keybinds
vim.keymap.set({ "n", "v" }, "<leader>ff", "<cmd>Telescope find_files hidden=true<CR>")
vim.keymap.set({ "n", "v" }, "<leader>fw", "<cmd>Telescope live_grep<CR>")
vim.keymap.set({ "n", "v" }, "<leader>fd", "<cmd>Telescope lsp_definitions<CR>")
vim.keymap.set({ "n", "v" }, "<leader>fs", "<cmd>Telescope lsp_workspace_symbols<CR>")
vim.keymap.set({ "n", "v" }, "<leader>b", "<cmd>Neotree toggle<CR>")

--- Buffer Keybinds
vim.keymap.set({ "n", "v" }, "<A-h>", "<cmd>bprevious<CR>")
vim.keymap.set({ "n", "v" }, "<A-l>", "<cmd>bnext<CR>")
vim.keymap.set({ "n", "v" }, "<A-t>", "<cmd>enew<CR>")

--- Window Keybinds
vim.keymap.set({ "n", "v" }, "<A-w>", "<cmd>bdelete<CR>")
vim.keymap.set({ "n", "v" }, '<C-w>"', "<cmd>sp<CR>")
vim.keymap.set({ "n", "v" }, "<C-w>%", "<cmd>vsp<CR>")

--- General Keybinds
vim.keymap.set({ "n", "v" }, "<C-s>", "<cmd>w<CR>")
