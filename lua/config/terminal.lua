-- Use PowerShell instead of cmd.exe on Windows (for :terminal, :! and
-- system()). These are the settings recommended by :help shell-powershell.
if vim.fn.has("win32") == 1 then
	vim.o.shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell"
	vim.o.shellcmdflag =
		"-NoLogo -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
	vim.o.shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait"
	vim.o.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
	vim.o.shellquote = ""
	vim.o.shellxquote = ""
end

-- Scrollback is a normal buffer in Normal mode, so a bigger limit means more
-- history to search/yank (default is 10000).
vim.o.scrollback = 100000

-- <Esc><Esc> (not a bare <Esc>, which TUI apps inside the terminal need)
-- goes from Terminal mode to Normal mode.
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Terminal: leave to Normal mode" })

vim.api.nvim_create_autocmd("TermOpen", {
	group = vim.api.nvim_create_augroup("termConfig", { clear = true }),
	desc = "Start new terminals in Terminal mode",
	callback = function()
		vim.cmd.startinsert()
	end,
})
