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

local termGroup = vim.api.nvim_create_augroup("termConfig", { clear = true })

vim.api.nvim_create_autocmd("TermOpen", {
	group = termGroup,
	desc = "Start new terminals in Terminal mode",
	callback = function()
		vim.cmd.startinsert()
	end,
})

-- Gutter numbers are only useful in Normal/Visual mode, where you navigate
-- with counts. Hide them while typing into the terminal.
local function setTermNumbers(enabled)
	vim.wo.number = enabled
	vim.wo.relativenumber = enabled
end

vim.api.nvim_create_autocmd("TermEnter", {
	group = termGroup,
	desc = "Hide line numbers in Terminal mode",
	callback = function()
		setTermNumbers(false)
	end,
})

vim.api.nvim_create_autocmd("TermLeave", {
	group = termGroup,
	desc = "Show relative line numbers outside Terminal mode",
	callback = function()
		setTermNumbers(true)
	end,
})
