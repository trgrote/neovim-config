-- Perl-specific config. The original's hardcoded Windows ctags path
-- (C:\Users\trg5\code\perl-modules\tags) is dropped per decision - relies
-- on Neovim's default 'tags' value instead.
vim.cmd("filetype indent on")
vim.cmd("filetype plugin on")

-- Fold subs/packages/POD via vim-perl's syntax folding, overriding the
-- global marker foldmethod (lua/config/options.lua) for Perl buffers only.
vim.g.perl_fold = 1
vim.opt_local.foldmethod = "syntax"
