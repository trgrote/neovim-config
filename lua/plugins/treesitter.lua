-- New addition: the original config had no treesitter. Also replaces
-- vim-javascript/vim-jsx (JS/JSX highlighting) and
-- junegunn/rainbow_parentheses.vim (via rainbow-delimiters.nvim).
--
-- Pinned to the "main" branch (the rewritten core API). The old "master"
-- branch monkey-patches vim.treesitter.LanguageTree and stopped being
-- compatible with current Neovim core, causing
-- "attempt to call method 'range' (a nil value)" errors during parsing.
local PARSERS = {
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
	"c_sharp",
	-- .csproj/.sln/.props are XML; neotest and easy-dotnet also parse them.
	"xml",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = ":TSUpdate",
		lazy = false,
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		config = function()
			require("nvim-treesitter").setup({
				install_dir = vim.fn.stdpath("data") .. "/site",
			})
			require("nvim-treesitter").install(PARSERS)
			require("nvim-treesitter-textobjects").setup({ select = { lookahead = true } })

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function()
					if pcall(vim.treesitter.start) then
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
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
