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
}
