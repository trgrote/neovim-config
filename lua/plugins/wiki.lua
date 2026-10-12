-- Kept as vimscript plugins (they *are* the plugins, not the user's own
-- config logic) - see lua/vimwiki/*.lua for the full Lua rewrite of the
-- custom automation layered on top of vimwiki.
--
-- vimwiki is loaded eagerly (not ft-lazy-loaded) because its own ftdetect
-- is what gives wiki *.md files the vimwiki filetype in the first place.
return {
	{
		"vimwiki/vimwiki",
		branch = "dev",
		lazy = false,
		init = function()
			-- Machine-specific wiki list, gitignored (see
			-- lua/vimwiki/wiki-list.lua.example). Falls back to
			-- vimwiki's own built-in default wiki if absent.
			local ok, wiki_list = pcall(require, "vimwiki.wiki-list")
			if not ok then
				if not wiki_list:find("module 'vimwiki.wiki-list' not found", 1, true) then
					vim.notify("lua/vimwiki/wiki-list.lua failed to load: " .. wiki_list, vim.log.levels.WARN)
				end
			elseif type(wiki_list) ~= "table" then
				vim.notify("lua/vimwiki/wiki-list.lua must return a table, got " .. type(wiki_list), vim.log.levels.WARN)
			else
				vim.g.vimwiki_list = wiki_list
			end

			vim.g.vimwiki_ext2syntax = {
				[".md"] = "markdown",
			}
			vim.g.vimwiki_folding = "expr"
			vim.g.calendar_action_end = "CloseCalendarBuffer"

			-- Vimwiki skips a default global mapping when its lhs is already
			-- mapped, so mapping these to <Nop> turns them off.
			vim.keymap.set("n", "<Leader>ww", "<Nop>")
			vim.keymap.set("n", "<Leader>w<Leader>w", "<Nop>")
			vim.keymap.set("n", "<Leader>wt", "<Nop>")
		end,
		config = function()
			-- calendar-vim (a vimscript plugin) calls this by name via
			-- g:calendar_action_end, so it has to be a real Vim function.
			vim.cmd([[
				function! CloseCalendarBuffer(day, month, year, week, dir)
					bwipeout! __Calendar
				endfunction
			]])

			-- Replaces <Leader>w<Leader>w: open today's diary entry. An
			-- optional count picks the wiki (e.g. :2Diary).
			vim.api.nvim_create_user_command("Diary", function(opts)
				vim.cmd(opts.count .. "VimwikiMakeDiaryNote")
			end, { count = 0, desc = "Open today's diary entry" })
		end,
	},

	{ "trgrote/calendar-vim", cmd = "Calendar" },
}
