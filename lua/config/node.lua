-- Pins the Node that Neovim (and every LSP server, formatter, and Mason
-- install it spawns) runs on to fnm's "nvim" alias, regardless of which Node
-- the launching shell had active or which directory/session Neovim is in.
-- Projects that need an older Node get it from fnm's --use-on-cd shell hook,
-- which never runs inside Neovim. Set up with:
--   fnm install --lts && fnm alias <version> nvim
-- A no-op (falls back to whatever node is on PATH) if the alias doesn't exist.
local is_win = vim.fn.has("win32") == 1
local home = vim.env.HOME or vim.env.USERPROFILE or ""

local fnm_dirs = {}
if vim.env.FNM_DIR and vim.env.FNM_DIR ~= "" then
	table.insert(fnm_dirs, vim.env.FNM_DIR)
elseif is_win then
	table.insert(fnm_dirs, (vim.env.APPDATA or "") .. "/fnm")
else
	table.insert(fnm_dirs, (vim.env.XDG_DATA_HOME or (home .. "/.local/share")) .. "/fnm")
	-- Older fnm releases defaulted to ~/.fnm
	table.insert(fnm_dirs, home .. "/.fnm")
end

for _, fnm_dir in ipairs(fnm_dirs) do
	-- Windows Node installs keep node.exe at the root; Unix ones use bin/
	local node_dir = fnm_dir .. "/aliases/nvim" .. (is_win and "" or "/bin")
	if is_win then
		node_dir = node_dir:gsub("/", "\\")
	end
	if vim.fn.isdirectory(node_dir) == 1 then
		vim.env.PATH = node_dir .. (is_win and ";" or ":") .. vim.env.PATH
		break
	end
end
