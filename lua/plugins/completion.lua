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
			-- Don't force a separate undo point when accepting a (non-snippet)
			-- completion - keep it merged into the same insert-mode undo
			-- block as the rest of what you typed, so a single `u` after
			-- leaving insert mode undoes the whole insertion, completion
			-- included, matching what `.` already redoes as one unit.
			accept = { create_undo_point = false },
		},
		keymap = { preset = "default" },
		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
