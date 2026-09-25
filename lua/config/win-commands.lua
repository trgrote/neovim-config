-- Windows-only commands - a no-op on other platforms, since these all shell
-- out to Windows-specific executables with no cross-platform equivalent.
if vim.fn.has("win32") ~= 1 then
	return
end

-- Open Windows File Explorer at the current buffer's file, with the file
-- selected.
vim.api.nvim_create_user_command("ShowInExplorer", function()
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

-- Open a PowerShell instance in the current buffer's directory.
vim.api.nvim_create_user_command("OpenInPowershell", function()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		vim.notify("Buffer has no file", vim.log.levels.ERROR)
		return
	end

	local dir = vim.fn.fnamemodify(path, ":h")
	vim.fn.jobstart({ "cmd.exe", "/c", "start", "powershell.exe" }, { detach = true, cwd = dir })
end, {})
