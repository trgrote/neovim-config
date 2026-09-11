-- New addition: the original config had no completion engine.
return {
	"saghen/blink.cmp",
	event = "InsertEnter",
	version = "1.*",
	opts = {
		completion = {
			-- Don't pop up automatically while typing - only on request
			-- (below: <C-n>/<C-p>, also <C-space> from the "default" preset).
			trigger = {
				show_on_keyword = false,
				show_on_trigger_character = false,
			},
		},
		keymap = {
			preset = "default",
			-- show() no-ops if the menu's already open (falls through to the
			-- next action), so these open the menu on first press and
			-- navigate it on subsequent presses, like classic i_CTRL-N/
			-- i_CTRL-P but backed by blink's LSP-aware completion.
			["<C-n>"] = { "show", "select_next", "fallback" },
			["<C-p>"] = { "show", "select_prev", "fallback" },
		},
		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
