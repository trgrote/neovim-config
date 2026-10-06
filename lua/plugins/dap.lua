-- Debugging core, shared by every language: nvim-dap itself, dap-ui,
-- inline virtual text, the keymaps, and the breakpoint signs.
--
-- Adapters and launch configurations live with their language instead:
--   * dotnet.lua - easy-dotnet registers netcoredbg (auto_register_dap)
--   * php.lua    - vscode-php-debug listening for Xdebug

return {
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
			-- Some adapters (php-debug in listen mode) just exit on terminate
			-- without sending either event above, so close on our own request too.
			dap.listeners.before.terminate.dapui = dapui.close
			dap.listeners.before.disconnect.dapui = dapui.close

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignInfo", linehl = "Visual" })
		end,
	},
}
