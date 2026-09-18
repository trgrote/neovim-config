-- Kept as vimscript plugins (they *are* the plugins, not the user's own
-- config logic) - see lua/vimwiki/*.lua for the full Lua rewrite of the
-- custom automation layered on top of vimwiki.
--
-- vimwiki is loaded eagerly (not ft-lazy-loaded) so the BufNewFile
-- autocmds below are registered before the very first new wiki/diary page
-- is created - vimwiki's own ftdetect converts a new *.md buffer's
-- filetype on BufNewFile, and lazy-loading on that FileType event would
-- fire too late to catch the BufNewFile event on the same buffer.
return {
	{
		"vimwiki/vimwiki",
		branch = "dev",
		lazy = false,
		init = function()
			vim.g.vimwiki_list = {
				{
					path = "~/vimwiki/mwl/",
					index = "Home",
					syntax = "markdown",
					ext = ".md",
				},
			}
			vim.g.vimwiki_ext2syntax = {
				[".md"] = "markdown",
				[".markdown"] = "markdown",
				[".mdown"] = "markdown",
			}
			vim.g.vimwiki_folding = "expr"
			vim.g.calendar_action_end = "CloseCalendarBuffer"
		end,
		config = function()
			-- calendar-vim (a vimscript plugin) calls this by name via
			-- g:calendar_action_end, so it has to be a real Vim function.
			vim.cmd([[
				function! CloseCalendarBuffer(day, month, year, week, dir)
					bwipeout! __Calendar
				endfunction
			]])

			local wiki_augroup = vim.api.nvim_create_augroup("wiki_templates", { clear = true })

			-- Populate any newly created *.md file from the wiki page skeleton.
			vim.api.nvim_create_autocmd("BufNewFile", {
				group = wiki_augroup,
				pattern = "*.md",
				callback = function(args)
					local skeleton = vim.fn.stdpath("config") .. "/templates/skeleton.md"
					vim.cmd("0read " .. vim.fn.fnameescape(skeleton))
				end,
			})

			-- New diary entries: populate from the diary skeleton, substitute the
			-- DATE placeholder, carry forward the previous day's incomplete
			-- TODOs, and regenerate the diary index.
			vim.api.nvim_create_autocmd("BufNewFile", {
				group = wiki_augroup,
				pattern = "*/diary/*.md",
				callback = function(args)
					local buf = args.buf
					local diary = require("vimwiki.diary")

					local skeleton_path = vim.fn.stdpath("config") .. "/templates/skeleton.diary.md"
					local lines = vim.fn.readfile(skeleton_path)

					local date = vim.fn.expand("%:t:r")
					local safe_date = date:gsub("%%", "%%%%")
					for i, line in ipairs(lines) do
						lines[i] = (line:gsub("DATE", safe_date))
					end
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

					diary.append_previous_todo(vim.fn.expand("%:t"))
					vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
					diary.update_diary_index()

					local lcount = vim.api.nvim_buf_line_count(buf)
					local target = math.max(lcount - 1, 1)
					local target_line = vim.api.nvim_buf_get_lines(buf, target - 1, target, false)[1] or ""
					vim.api.nvim_win_set_cursor(0, { target, #target_line })
				end,
			})
		end,
	},

	{ "trgrote/calendar-vim", cmd = "Calendar" },
}
