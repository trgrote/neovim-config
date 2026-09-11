-- New addition: the original config had no completion engine.
return {
	"saghen/blink.cmp",
	event = "InsertEnter",
	version = "1.*",
	opts = {
		completion = {
			-- Don't pop up automatically while typing - only on request, via
			-- <C-space> (from the "default" keymap preset below).
			trigger = {
				show_on_keyword = false,
				show_on_trigger_character = false,
			},
		},
		keymap = { preset = "default" },
		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
