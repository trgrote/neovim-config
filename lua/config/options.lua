local opt = vim.opt

-- Statusline content/format is owned by lualine.nvim (lua/plugins/ui.lua)
-- once it loads - it overrides 'laststatus'/'statusline' itself, so there
-- is nothing to set here.

-- Ignore case, unless the search contains a capital letter
opt.ignorecase = true
opt.smartcase = true

opt.showmatch = true
opt.cindent = true
opt.errorbells = false
opt.showcmd = true
opt.mouse = "a"

-- Line numbers
opt.relativenumber = true
opt.number = true

-- Tab settings: 4 spaces = tab
opt.tabstop = 4
opt.softtabstop = 0
opt.shiftwidth = 4
opt.expandtab = false
opt.copyindent = true
opt.preserveindent = false

opt.list = true
opt.listchars = { tab = ">-", trail = "*" }

opt.linebreak = true
-- Neovim's default formatoptions is "tcqj" - keep its 'j' (strip comment
-- leader when joining) on top of the original's "cqt".
opt.formatoptions = "cqtj"

opt.backup = false
opt.swapfile = false

opt.foldmethod = "marker"

opt.spellsuggest:append("10")

opt.splitright = true

opt.wildignore = { "*/node_modules/*", "*/vendor/*" }

-- Disable weird background highlighting that happens for list characters;
-- must be reapplied on every colorscheme change since plugins overwrite it
vim.api.nvim_create_augroup("SpecialKeyHighlight", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = "SpecialKeyHighlight",
  callback = function()
    vim.api.nvim_set_hl(0, "SpecialKey", { bg = "NONE" })
  end,
})
vim.api.nvim_set_hl(0, "SpecialKey", { bg = "NONE" })
