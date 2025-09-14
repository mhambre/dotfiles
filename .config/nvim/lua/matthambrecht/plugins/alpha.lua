return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Set header
    dashboard.section.header.val = {
      "░███     ░███               ░██       ░██    ░██    ░██ ░██                ",
      "░████   ░████               ░██       ░██    ░██    ░██                    ",
      "░██░██ ░██░██  ░██████   ░████████ ░████████ ░██    ░██ ░██░█████████████  ",
      "░██ ░████ ░██       ░██     ░██       ░██    ░██    ░██ ░██░██   ░██   ░██ ",
      "░██  ░██  ░██  ░███████     ░██       ░██     ░██  ░██  ░██░██   ░██   ░██ ",
      "░██       ░██ ░██   ░██     ░██       ░██      ░██░██   ░██░██   ░██   ░██ ",
      "░██       ░██  ░█████░██     ░████     ░████    ░███    ░██░██   ░██   ░██ ",
    }

    -- Set menu
    dashboard.section.buttons.val = {
      dashboard.button("ALT t", "  > New File", "<cmd>ene<CR>"),
      dashboard.button("SPACE b", "  > Toggle file explorer", "<cmd>NvimTreeToggle<CR>"),
      dashboard.button("SPACE ff", "󰱼 > Find File", "<cmd>Telescope find_files<CR>"),
      dashboard.button("SPACE fw", "  > Find Word", "<cmd>Telescope live_grep<CR>"),
      dashboard.button("q", " > Quit NVIM", "<cmd>qa<CR>"),
    }

    -- Send config to alpha
    alpha.setup(dashboard.opts)

    -- Disable folding on alpha buffer
    vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
  end,
}
