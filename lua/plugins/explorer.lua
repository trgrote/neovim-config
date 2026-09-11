-- File explorer, replacing scrooloose/nerdtree.
return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<F1>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
  },
  opts = {
    filters = {
      custom = { "\\.meta$" },
    },
  },
}
