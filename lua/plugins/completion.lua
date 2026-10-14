-- New addition: the original config had no completion engine.
return {
	"saghen/blink.cmp",
	event = "InsertEnter",
	version = "1.*",
	opts = {
		-- Only turn blink on for actual code, not prose (markdown/vimwiki
		-- notes) - no popup at all there, manual trigger included.
		enabled = function()
			return vim.bo.filetype ~= "markdown" and vim.bo.filetype ~= "vimwiki"
		end,
		completion = {
			-- Don't force a separate undo point when accepting a (non-snippet)
			-- completion - keep it merged into the same insert-mode undo
			-- block as the rest of what you typed, so a single `u` after
			-- leaving insert mode undoes the whole insertion, completion
			-- included, matching what `.` already redoes as one unit.
			accept = {
				create_undo_point = false,
				-- Accepting a method just finishes its name; don't insert a
				-- `()` pair around the cursor. Typing `);<Esc>` by hand is
				-- less work than escaping to append the `;` afterwards.
				auto_brackets = { enabled = false },
			},
		},
		keymap = { preset = "default" },
		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
