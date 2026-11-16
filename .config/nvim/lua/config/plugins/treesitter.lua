local ensure_installed = {
  "lua",
  "vim",
  "vimdoc",
  "python",
  "javascript",
  "typescript",
  "tsx",
  "svelte",
  "html",
  "css",
  "graphql",
  "http",
  "prisma",
  "rust",
  "go",
  "c",
  "cpp",
  "bash",
  "json",
  "yaml",
  "toml",
  "markdown",
  "markdown_inline",
}

return {
  "nvim-treesitter/nvim-treesitter",
  -- main branch requires nvim 0.12
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    ts.install(ensure_installed)

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter_start", {}),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then
          return
        end

        local function start()
          vim.treesitter.start(args.buf, lang)
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end

        if vim.treesitter.language.add(lang) then
          start()
        elseif vim.tbl_contains(ts.get_available(), lang) then
          -- install missing parsers when entering a buffer
          ts.install(lang):await(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              start()
            end
          end)
        end
      end,
    })
  end,
}
