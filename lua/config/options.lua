local opt = vim.opt

-- Statusline
opt.laststatus = 2
opt.statusline = table.concat({
  "%F%m%r%h%w",
  "[FORMAT=%{&ff}]",
  "[TYPE=%Y]",
  "[POS=%l,%v][%p%%]",
  "%{strftime('%d/%m/%y - %H:%M')}",
}, " ")

opt.hidden = true

-- Ignore case, unless the search contains a capital letter
opt.ignorecase = true
opt.smartcase = true

opt.backspace = { "indent", "eol", "start" }

opt.incsearch = true
opt.hlsearch = true
opt.showmatch = true
opt.cindent = true
opt.ruler = true
opt.errorbells = false
opt.showcmd = true
opt.mouse = "a"
opt.history = 1000
opt.undolevels = 1000

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

opt.wrap = true
-- Disable automatic newline insertion after X amount of chars
opt.textwidth = 0
opt.linebreak = true
opt.wrapmargin = 0
opt.formatoptions = "cqt"
opt.lazyredraw = true -- don't redraw during a macro run

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
