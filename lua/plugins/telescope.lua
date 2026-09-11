-- Fuzzy finder, replacing ctrlpvim/ctrlp.vim.
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    {
      "<c-p>",
      function()
        -- Replaces ctrlp_working_path_mode='ra': search from the nearest
        -- ancestor directory containing a .git marker, not just Neovim's
        -- current :pwd. Falls back to :pwd if no marker is found.
        local root = vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
        require("telescope.builtin").find_files({ cwd = root })
      end,
      desc = "Find files (project root)",
    },
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
