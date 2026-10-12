local augroup = vim.api.nvim_create_augroup("vimrcEx", { clear = true })

-- Reload a buffer automatically when its file changes on disk (e.g. an
-- external tool edits it), as long as the buffer has no unsaved changes of
-- its own. `autoread` only takes effect when something triggers :checktime,
-- so poke it on the events where an external change is likely to have
-- happened.
vim.opt.autoread = true

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = augroup,
	desc = "Check for external file changes",
	callback = function()
		if vim.fn.mode() ~= "c" then
			vim.cmd("checktime")
		end
	end,
})

-- For text files, wrap at 78 characters
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "text",
	callback = function()
		vim.opt_local.textwidth = 78
	end,
})

-- When editing a file, jump to the last known cursor position, unless the
-- position is invalid, the mark is on the first line (the default position
-- when opening a file), or the filetype is one where this would be
-- unwelcome (commit messages, interactive rebase, binary/xxd views).
-- Neovim does not do this by default (unlike some assumptions about Vim
-- defaults) - see :h restore-cursor.
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	callback = function(args)
		local exclude_filetypes = { "commit", "gitrebase", "xxd" }
		if vim.tbl_contains(exclude_filetypes, vim.bo[args.buf].filetype) then
			return
		end
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		local lcount = vim.api.nvim_buf_line_count(args.buf)
		if mark[1] > 1 and mark[1] <= lcount then
			vim.api.nvim_win_set_cursor(0, { mark[1], mark[2] })
		end
	end,
})

-- Populate new files from the first matching template rule in
-- <cwd>/.templates/rules.json, then templates/rules.json in this config (see
-- lua/util/templates.lua). Registered here, before lazy.nvim loads any
-- plugins, so it's in place for the very first new file.
vim.api.nvim_create_autocmd("BufNewFile", {
	group = augroup,
	desc = "Apply file template",
	callback = function(args)
		require("util.templates").on_new_file(args)
	end,
})

-- oil.nvim creates new files directly on disk (no BufNewFile), so fill
-- them from their template right after oil's actions complete.
vim.api.nvim_create_autocmd("User", {
	group = augroup,
	pattern = "OilActionsPost",
	desc = "Apply file template to files created in oil",
	callback = function(args)
		if args.data.err then
			return
		end
		for _, action in ipairs(args.data.actions) do
			if action.type == "create" and action.entry_type == "file" then
				local scheme, path = require("oil.util").parse_url(action.url)
				if scheme == "oil://" then
					require("util.templates").fill_file(require("oil.fs").posix_to_os_path(path))
				end
			end
		end
	end,
})

vim.api.nvim_create_user_command("Template", function(opts)
	require("util.templates").apply_by_name(opts.args, opts.bang)
end, {
	nargs = 1,
	bang = true,
	desc = "Apply a template to the current buffer (! replaces existing content)",
	complete = function(arg_lead)
		return vim.tbl_filter(function(name)
			return vim.startswith(name, arg_lead)
		end, require("util.templates").template_names())
	end,
})
