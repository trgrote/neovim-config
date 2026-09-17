-- Open Windows File Explorer at the current buffer's file, with the file
-- selected. Windows-only: shells out to explorer.exe, which has no
-- equivalent on other platforms.
vim.api.nvim_create_user_command("ShowInExplorer", function()
	if vim.fn.has("win32") ~= 1 then
		vim.notify("ShowInExplorer is Windows-only", vim.log.levels.ERROR)
		return
	end

	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		vim.notify("Buffer has no file", vim.log.levels.ERROR)
		return
	end

	-- /select, and the quoted path must form a single argument with no
	-- space in between, or explorer opens the path instead of selecting it.
	local winpath = path:gsub("/", "\\")
	vim.fn.jobstart(string.format('explorer.exe /select,"%s"', winpath), { detach = true })
end, {})
