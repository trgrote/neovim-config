-- Floating, buffer-based file explorer (edit the filesystem like a normal
-- buffer). Replaces nvim-tree/<F1>.
return {
	"stevearc/oil.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	lazy = false, -- must load before netrw would, to intercept directory opens
	keys = {
		{
			"<leader>e",
			function()
				require("oil").open_float(require("util.oil").buffer_dir())
			end,
			desc = "Explorer (oil, relative to buffer)",
		},
		{
			"<leader>E",
			function()
				require("oil").open_float(vim.uv.cwd())
			end,
			desc = "Explorer (oil, relative to cwd)",
		},
	},
	opts = {
		default_file_explorer = true, -- replace netrw for directory-open paths too
		delete_to_trash = true,
		view_options = {
			show_hidden = true,
			is_always_hidden = function(name)
				return name:match("%.meta$") ~= nil
			end,
		},
		float = {
			padding = 4,
			max_width = 90,
			border = "rounded",
		},
	},
}
