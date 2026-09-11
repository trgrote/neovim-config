return {
	-- Lua-native replacement for tpope/vim-surround; defaults match the
	-- original config (no custom overrides were used: ys/cs/ds/S).
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = true,
	},

	-- Kept as-is: no mature Lua-native alignment plugin replaces it.
	{
		"godlygeek/tabular",
		cmd = "Tabularize",
		keys = {
			{ "<leader>tj", "viB:Tabularize /^[^:]*\\zs:<CR>", mode = "n" },
			{ "<leader>t=", "viB:Tabularize /=<CR>", mode = "n", silent = true },
			{ "<leader>t/", ":Tabularize /\\/\\//l4l1<CR>", mode = "v", silent = true },
			{ "<leader>t=", ":Tabularize /=<CR>", mode = "v", silent = true },
			{ "<leader>tj", ":Tabularize /^[^:]*\\zs:<CR>", mode = "v", silent = true },
			{ "<leader>t#", ":Tabularize /#/l4l1<CR>", mode = "v", silent = true },
			{ "<leader>t=>", ":Tabularize /=><CR>", mode = "v", silent = true },
		},
	},

	-- Kept as-is: no mature Lua-native argument-wrap replaces it.
	{
		"FooSoft/vim-argwrap",
		cmd = "ArgWrap",
		keys = {
			{ "<leader>a", "<cmd>ArgWrap<CR>", desc = "Toggle arg wrap" },
		},
	},
}
