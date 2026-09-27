-- Named marks (lua/util/named-marks.lua) are in-memory and session-agnostic;
-- this file is what scopes them to the active auto-session session, by
-- clearing/saving/loading a JSON file keyed by session name around
-- auto-session's own save/restore hooks.
local function marks_file_for(session_name)
	local dir = vim.fn.stdpath("data") .. "/named-marks"
	vim.fn.mkdir(dir, "p")
	return dir .. "/" .. vim.fn.sha256(session_name) .. ".json"
end

local function save_marks()
	local session_name = require("auto-session.lib").current_session_name()
	local ok, encoded = pcall(vim.json.encode, require("util.named-marks").export())
	if ok then
		vim.fn.writefile({ encoded }, marks_file_for(session_name))
	end
end

local function load_marks()
	local session_name = require("auto-session.lib").current_session_name()
	local path = marks_file_for(session_name)
	if vim.fn.filereadable(path) == 0 then
		return
	end
	local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
	if ok and type(decoded) == "table" then
		require("util.named-marks").import(decoded)
	end
end

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
		-- Set the flag directly instead of calling disable_auto_save(true),
		-- which unconditionally vim.notify()'s "Session auto-save enabled"
		-- every time - there's no config option to silence it.
		post_save_cmds = {
			function()
				require("auto-session.config").auto_save = true
			end,
			save_marks,
		},
		post_restore_cmds = {
			function()
				require("auto-session.config").auto_save = true
			end,
			-- Clear stale marks from whatever was loaded before, then load
			-- the new session's own marks (if it has any saved). Both run
			-- only once the restore has actually succeeded - if sourcing the
			-- session file errors, auto-session skips post_restore_cmds
			-- entirely, so the previous marks are left alone rather than
			-- being cleared and never replaced.
			function()
				require("util.named-marks").clear()
				load_marks()
			end,
		},
	},
}
