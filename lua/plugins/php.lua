-- PHP debugging via Xdebug, using vscode-php-debug (`:MasonInstall
-- php-debug-adapter`) as the DAP adapter.
--
-- Xdebug runs wherever PHP runs (here usually a Docker container) and
-- connects *out* to the adapter, which listens on 9003 on this machine. So
-- the flow is: start the "Listen for Xdebug" session with <F5> first, then
-- trigger a request/CLI run with XDEBUG_TRIGGER=1.
--
-- Registered from `init` rather than `config` so this spec doesn't replace the
-- nvim-dap `config` function in dap.lua (lazy.nvim merges `keys`/`opts`
-- across specs but lets a later `config` win outright).

local function getPhpDebugAdapterPath()
	return vim.fn.stdpath("data") .. "/mason/packages/php-debug-adapter/extension/out/phpDebug.js"
end

local function registerPhpDebugging()
	local dap = require("dap")

	dap.adapters.php = {
		type = "executable",
		command = "node",
		args = { getPhpDebugAdapterPath() },
	}

	dap.configurations.php = {
		{
			type = "php",
			request = "launch",
			name = "Listen for Xdebug (docker: /var/www/mwl_api)",
			port = 9003,
			-- Container path -> host path. Neovide must be started from the
			-- repo root so cwd is the directory that's bind-mounted.
			pathMappings = function()
				return { ["/var/www/mwl_api"] = vim.fn.getcwd() }
			end,
		},
		{
			type = "php",
			request = "launch",
			name = "Listen for Xdebug (local PHP, no mapping)",
			port = 9003,
		},
	}
end

return {
	{
		"mfussenegger/nvim-dap",
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "php",
				once = true,
				callback = registerPhpDebugging,
			})
		end,
	},
}
