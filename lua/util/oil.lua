local M = {}

--- Directory to open oil.nvim in for <leader>e: the current buffer's file
--- directory, or cwd if the buffer isn't a normal file buffer.
function M.buffer_dir()
	if vim.bo.filetype == "oil" then
		return require("oil").get_current_dir()
	end

	local bufname = vim.api.nvim_buf_get_name(0)
	local buftype = vim.bo.buftype

	if buftype ~= "" or bufname == "" then
		return vim.uv.cwd()
	end

	return vim.fn.fnamemodify(bufname, ":p:h")
end

return M
