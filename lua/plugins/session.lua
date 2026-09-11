return {
	"rmagatti/auto-session",
	lazy = false,
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{ "<Leader>p", "<cmd>AutoSession search<CR>", desc = "Find/switch session" },
	},
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		-- Don't auto-create/restore sessions in these directories - avoids an
		-- accidental giant session for the home directory itself, etc.
		suppressed_dirs = { "~/", "~/Downloads", "/" },
	},
}
