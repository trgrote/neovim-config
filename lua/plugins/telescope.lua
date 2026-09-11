-- Fuzzy finder, replacing ctrlpvim/ctrlp.vim.
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    { "<c-p>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
    -- Named to avoid any collision with vimwiki's buffer-local <Leader>fb
    -- (bold text-object surround, ftplugin/vimwiki.lua).
    { "<leader>bl", "<cmd>Telescope buffers<CR>", desc = "List buffers" },
  },
  opts = {
    defaults = {
      -- Replaces ctrlp_custom_ignore's dir/file regexes.
      file_ignore_patterns = {
        "node_modules/",
        "target/",
        "dist/",
        "%.git/",
        "%.svn/",
        "%.swp$",
        "%.ico$",
        "%.exe$",
        "%.so$",
        "%.dll$",
        "%.meta$",
        "%.csproj$",
        "%.sln$",
        "%.manifest$",
        "%.suo$",
        "%.pdb$",
        "%.user$",
        "%.jmconfig$",
      },
    },
  },
  config = function(_, opts)
    require("telescope").setup(opts)
    pcall(require("telescope").load_extension, "fzf")
  end,
}
