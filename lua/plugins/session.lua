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
		-- No automatic save-on-exit or restore-on-startup - sessions are
		-- opt-in only, via :AutoSession save/restore/search (<Leader>p) or
		-- the dashboard's "Open session" button.
		auto_save = false,
		auto_restore = false,

		-- Don't auto-create/restore sessions in these directories - avoids an
		-- accidental giant session for the home directory itself, etc.
		suppressed_dirs = { "~/", "~/Downloads", "/" },
	},
}
