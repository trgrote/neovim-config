-- LSP (Language Server Protocol): editor integration with language servers
-- for diagnostics, completion, go-to-definition, etc.
return {
	{
		"mason-org/mason.nvim",
		config = true,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		opts = {
			ensure_installed = { "lua_ls", "ts_ls", "jsonls", "bashls", "intelephense" },
		},
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			vim.lsp.enable({ "lua_ls", "ts_ls", "jsonls", "bashls", "intelephense" })
		end,
	},
	-- Inline diagnostic message shown only on the cursor's current line,
	-- replacing the built-in end-of-line virtual text.
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		priority = 1000,
		config = function()
			require("tiny-inline-diagnostic").setup({
				options = {
					show_diags_only_under_cursor = true,
				},
			})
			vim.diagnostic.config({ virtual_text = false })
		end,
	},
}
