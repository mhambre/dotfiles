------------------------------
---- NeoVim Configuration ----
------------------------------

-- Global Variables
--- Theme
vim.opt.termguicolors = true
vim.cmd [[
  hi Normal ctermbg=none guibg=none
  hi NormalNC ctermbg=none guibg=none
  hi SignColumn ctermbg=none guibg=none
  hi EndOfBuffer ctermbg=none guibg=none
]]

--- Line Numbers
vim.wo.number = true
vim.wo.relativenumber = true

--- Spacing
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Plugins
vim.opt.rtp:prepend("~/.config/nvim/lazy/lazy.nvim")

require("lazy").setup({
  {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      ensure_installed = { "all" },
      highlight = {
          enable = true
      }
  },
  {
      "nvim-telescope/telescope.nvim",
      dependencies = {
          "nvim-lua/plenary.nvim"
      }
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")

      local on_attach = function(_, bufnr)
        local opts = { buffer = bufnr, silent = true, noremap = true }
        vim.keymap.set("n", "<A-d>", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      end

      -- Setup Pyright for Python
      lspconfig.pyright.setup({
        on_attach = on_attach,
      })
    end,
  },
})

-- Keybinds
vim.keymap.set({ "n", "v" }, "<A-f>", "<cmd>Telescope find_files<CR>")
vim.keymap.set({ "n", "v" }, "<A-b>", "<cmd>Neotree<CR>")
