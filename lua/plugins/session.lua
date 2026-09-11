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

		-- Once a session has been explicitly saved or restored this run,
		-- turn autosave on for the rest of it - so further changes (e.g.
		-- opening another file) get captured on quit, into that same named
		-- session (auto-session tracks v:this_session once manually named,
		-- so this doesn't create a separate cwd-derived session instead).
		post_save_cmds = {
			function()
				require("auto-session").disable_auto_save(true)
			end,
		},
		post_restore_cmds = {
			function()
				require("auto-session").disable_auto_save(true)
			end,
		},
	},
}
