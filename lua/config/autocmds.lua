local augroup = vim.api.nvim_create_augroup("vimrcEx", { clear = true })

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
