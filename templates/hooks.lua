-- Code for the template system (see lua/util/templates.lua). Rules files
-- (here and in local .templates/ folders) are plain JSON; anything that
-- needs Lua lives here.
return {
	-- Extra placeholders available to every template, e.g. {{month}}.
	-- Functions are called with ctx when the file is created.
	-- Multi-line values are split into separate lines.
	vars = {
		-- Incomplete TODOs carried forward from the previous diary entry in
		-- the same folder (see skeleton.diary.md).
		previous_todos = function(ctx)
			return table.concat(require("vimwiki.diary").get_previous_todos(ctx.file), "\n")
		end,
	},

	-- Hooks run after a template populates a buffer, referenced from a
	-- rule by name: "post": "diary".
	post = {
		-- Vimwiki diary entries: regenerate the diary index so it links the
		-- new entry (this saves the entry first).
		diary = function()
			require("vimwiki.diary").update_diary_index()
		end,
	},
}
