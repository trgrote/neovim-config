-- C#-specific config.

-- Fold using Roslyn's folding ranges (#region blocks, classes, methods,
-- usings, etc.), overriding the global marker foldmethod
-- (lua/config/options.lua) for C# buffers only. Folds appear once roslyn
-- has attached and loaded the solution.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.lsp.foldexpr()"
-- Keep the class body open; regions and members inside it start closed.
vim.opt_local.foldlevel = 1
