-- New addition: the original config had no treesitter. Also replaces
-- vim-javascript/vim-jsx (JS/JSX highlighting) and
-- junegunn/rainbow_parentheses.vim (via rainbow-delimiters.nvim).
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- pin to the classic configs.setup API
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua",
          "vim",
          "vimdoc",
          "query",
          "javascript",
          "tsx",
          "json",
          "markdown",
          "markdown_inline",
          "bash",
        },
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      })
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("rainbow-delimiters.setup").setup({
        query = { [""] = "rainbow-delimiters" },
      })
    end,
  },
}
