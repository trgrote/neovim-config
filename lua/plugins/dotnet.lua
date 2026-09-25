-- C#/.NET development: Roslyn LSP, netcoredbg debugging, and a Rider-style
-- test runner.
--
-- Three pieces, deliberately kept separate:
--   * roslyn.nvim  - the LSP only. Wraps nvim-lspconfig's `roslyn_ls` and adds
--                    the parts lspconfig won't do: discovering *every* .sln in
--                    a tree and letting you switch between them (:Roslyn
--                    target). OmniSharp is not used - it's been superseded by
--                    Microsoft's own Roslyn language server.
--   * easy-dotnet  - build/run/test/package management (:Dotnet ...), plus the
--                    test runner tree and a neotest adapter. Its own bundled
--                    LSP support is switched off so roslyn.nvim owns that and
--                    there's only ever one C# client attached.
--   * nvim-dap     - debugging, driven by netcoredbg (installed via Mason).
--
-- External dependencies (see Install-Dotnet.ps1):
--   dotnet SDK, `dotnet tool install -g EasyDotnet`,
--   `dotnet tool install -g roslyn-language-server --prerelease`,
--   `:MasonInstall netcoredbg`.

-- netcoredbg has no single canonical install location on Windows: Mason
-- extracts the upstream zip verbatim (packages/netcoredbg/netcoredbg/
-- netcoredbg.exe) and also drops a shim in mason/bin, while a manual install
-- just lands somewhere on PATH. Prefer the real executable over the .cmd shim
-- so nvim-dap spawns the debugger directly rather than through cmd.exe.
local function netcoredbg_path()
	local mason = vim.fn.stdpath("data") .. "/mason"
	local candidates = {
		mason .. "/packages/netcoredbg/netcoredbg/netcoredbg.exe",
		mason .. "/packages/netcoredbg/netcoredbg",
		mason .. "/bin/netcoredbg.cmd",
	}
	for _, path in ipairs(candidates) do
		if vim.fn.executable(path) == 1 then
			return path
		end
	end
	return "netcoredbg"
end

return {
	-- LSP. Lazy-loaded on C# filetypes; the server itself is the
	-- `roslyn-language-server` dotnet global tool, which nvim-lspconfig's
	-- roslyn_ls definition finds on PATH.
	{
		"seblyng/roslyn.nvim",
		ft = { "cs", "razor" },
		dependencies = { "neovim/nvim-lspconfig" },
		---@module 'roslyn.config'
		---@type RoslynNvimConfig
		opts = {
			-- Walk *down* into child directories looking for solutions too, not
			-- just up from the current file. Without this, opening a file in a
			-- repo whose .sln lives in a subdirectory attaches no server.
			broad_search = true,
		},
	},

	-- Build / run / test / solution + NuGet management, and the test runner UI.
	{
		"GustavEikaas/easy-dotnet.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"mfussenegger/nvim-dap",
		},
		ft = { "cs", "fsharp", "razor", "xml" },
		cmd = "Dotnet",
		keys = {
			{ "<leader>nt", "<cmd>Dotnet testrunner<CR>", desc = ".NET: test runner" },
			{ "<leader>nb", "<cmd>Dotnet build<CR>", desc = ".NET: build" },
			{ "<leader>nB", "<cmd>Dotnet build solution<CR>", desc = ".NET: build solution" },
			{ "<leader>nr", "<cmd>Dotnet run<CR>", desc = ".NET: run" },
			{ "<leader>nR", "<cmd>Dotnet run default<CR>", desc = ".NET: run last-picked project" },
			{ "<leader>nd", "<cmd>Dotnet debug<CR>", desc = ".NET: debug" },
			{ "<leader>nw", "<cmd>Dotnet watch<CR>", desc = ".NET: watch" },
			{ "<leader>nx", "<cmd>Dotnet clean<CR>", desc = ".NET: clean" },
			{ "<leader>np", "<cmd>Dotnet add package<CR>", desc = ".NET: add NuGet package" },
			{ "<leader>nP", "<cmd>Dotnet outdated<CR>", desc = ".NET: outdated packages" },
			{ "<leader>ns", "<cmd>Dotnet solution select<CR>", desc = ".NET: select solution" },
			{ "<leader>nn", "<cmd>Dotnet new<CR>", desc = ".NET: new project/file" },
		},
		opts = {
			picker = "telescope",
			-- roslyn.nvim owns the LSP; running easy-dotnet's too would attach a
			-- second C# client and duplicate every diagnostic.
			lsp = { enabled = false },
			debugger = {
				bin_path = netcoredbg_path(),
				-- Registers an "easy-dotnet" adapter plus a `cs` launch
				-- configuration with nvim-dap, so `:Dotnet debug` and plain dap
				-- <F5> both work without hand-writing a launch config.
				auto_register_dap = true,
			},
			test_runner = {
				viewmode = "float",
				-- Not optional if you want neotest: easy-dotnet's neotest adapter
				-- reads the test runner's state, so until the runner has started
				-- and discovered tests, neotest reports no tests at all. This
				-- starts it silently in the background when the server loads a
				-- solution, so <leader>nS works without opening the runner first.
				auto_start_testrunner = true,
				-- Mirror discovered tests into neotest (gutter signs, :Neotest
				-- summary) on top of easy-dotnet's own runner window.
				neotest_integration = true,
			},
			-- Fill in `namespace ...;` when creating a new .cs file.
			auto_bootstrap_namespace = { type = "file_scoped", enabled = true },
		},
	},

	-- Debugging.
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			{ "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
			"theHamsta/nvim-dap-virtual-text",
		},
		keys = {
			{
				"<F5>",
				function()
					require("dap").continue()
				end,
				desc = "Debug: continue/start",
			},
			{
				"<F10>",
				function()
					require("dap").step_over()
				end,
				desc = "Debug: step over",
			},
			{
				"<F11>",
				function()
					require("dap").step_into()
				end,
				desc = "Debug: step into",
			},
			{
				"<S-F11>",
				function()
					require("dap").step_out()
				end,
				desc = "Debug: step out",
			},
			-- Leader-key duplicates of the F-key step motions. <S-F11> in
			-- particular doesn't survive every terminal, so step-out needs a
			-- binding that's always reachable.
			{
				"<leader>dn",
				function()
					require("dap").step_over()
				end,
				desc = "Debug: step over (next)",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Debug: step into",
			},
			{
				"<leader>do",
				function()
					require("dap").step_out()
				end,
				desc = "Debug: step out",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Debug: toggle breakpoint",
			},
			{
				"<leader>dB",
				function()
					vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
						if cond and cond ~= "" then
							require("dap").set_breakpoint(cond)
						end
					end)
				end,
				desc = "Debug: conditional breakpoint",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Debug: continue/start",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Debug: toggle REPL",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Debug: re-run last",
			},
			{
				"<leader>dq",
				function()
					require("dap").terminate()
				end,
				desc = "Debug: terminate",
			},
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "Debug: toggle UI",
			},
			{
				"<leader>dh",
				function()
					require("dap.ui.widgets").hover()
				end,
				mode = { "n", "v" },
				desc = "Debug: hover value",
			},
		},
		config = function()
			local dap, dapui = require("dap"), require("dapui")

			dapui.setup()
			require("nvim-dap-virtual-text").setup({})

			-- Open/close the UI alongside the session so there's nothing extra to
			-- remember beyond <F5>.
			dap.listeners.before.attach.dapui = dapui.open
			dap.listeners.before.launch.dapui = dapui.open
			dap.listeners.before.event_terminated.dapui = dapui.close
			dap.listeners.before.event_exited.dapui = dapui.close

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignInfo", linehl = "Visual" })
		end,
	},

	-- Test UI. easy-dotnet supplies the adapter, so discovery/run state is
	-- shared with its own runner window rather than duplicated.
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"GustavEikaas/easy-dotnet.nvim",
		},
		keys = {
			{
				"<leader>nS",
				function()
					require("neotest").summary.toggle()
				end,
				desc = ".NET: neotest summary",
			},
			{
				"<leader>nf",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = ".NET: run tests in file",
			},
			{
				"<leader>nc",
				function()
					require("neotest").run.run()
				end,
				desc = ".NET: run nearest test",
			},
			{
				"<leader>no",
				function()
					require("neotest").output.open({ enter = true })
				end,
				desc = ".NET: test output",
			},
		},
		config = function()
			require("neotest").setup({
				adapters = { require("easy-dotnet.neotest") },
			})
		end,
	},
}
