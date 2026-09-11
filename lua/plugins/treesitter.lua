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
			-- Deferred + pcall-wrapped: ensure_installed's parser compilation can
			-- hard-error (e.g. no C compiler on PATH) instead of just warning,
			-- and since this config function runs from inside whatever
			-- autocmd/command chain triggered the plugin's lazy-load (opening a
			-- buffer, running a user command), an uncaught error here would
			-- otherwise abort that unrelated caller too.
			vim.schedule(function()
				local ok, err = pcall(function()
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
				end)
				if not ok then
					vim.notify("nvim-treesitter setup failed: " .. tostring(err), vim.log.levels.WARN)
				end
			end)
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
