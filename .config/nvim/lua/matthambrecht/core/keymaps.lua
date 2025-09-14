-- Keybinds
--- Plugin Keybinds
vim.keymap.set({ "n", "v" }, "<space>ff", "<cmd>Telescope find_files hidden=true<CR>")
vim.keymap.set({ "n", "v" }, "<space>fw", "<cmd>Telescope live_grep<CR>")
vim.keymap.set({ "n", "v" }, "<space>b", "<cmd>Neotree<CR>")
vim.keymap.set({ "n", "v" }, "<space>g", "<cmd>LazyGit<CR>")

--- Buffer Keybinds
vim.keymap.set({ "n", "v" }, "<A-h>", "<cmd>bprevious<CR>")
vim.keymap.set({ "n", "v" }, "<A-l>", "<cmd>bnext<CR>")
vim.keymap.set({ "n", "v" }, "<A-t>", "<cmd>enew<CR>")

--- Window Keybinds
vim.keymap.set({ "n", "v" }, "<A-w>", "<cmd>bdelete<CR>")
vim.keymap.set({ "n", "v" }, "<C-w>\"", "<cmd>sp<CR>")
vim.keymap.set({ "n", "v" }, "<C-w>%", "<cmd>vsp<CR>")
