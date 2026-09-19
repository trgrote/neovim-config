-- Fuzzy-find any file in the current vimwiki and insert a `[[/relative/path]]`
-- link at the cursor, instead of relying on Vim's built-in i_CTRL-X_CTRL-F
-- file completion (which can't resolve vimwiki's wiki-root-relative leading
-- '/', doesn't search outside 'path', and can't match filenames containing
-- spaces since it bases its "current word" on 'isfname').
local M = {}

-- vim.fs.normalize collapses doubled/mixed separators and resolves '.'/'..',
-- unlike a plain fnamemodify(":p") + gsub - needed because plenary's Path
-- joining (used internally by Telescope's file entries) inserts its own '/'
-- between cwd and a file's relative path regardless of whether cwd already
-- ends in one, which would otherwise produce a doubled separator. Trailing
-- slashes are stripped so root<->prefix comparisons don't have to guess
-- whether one is present.
local function normalize(path)
	return (vim.fs.normalize(path):gsub("/+$", ""))
end

-- The current buffer's wiki root, same value vimwiki itself resolves links
-- against. Falls back to cwd if the buffer somehow isn't assigned to a wiki.
local function wiki_root()
	local ok, root = pcall(vim.fn["vimwiki#vars#get_wikilocal"], "path")
	if not ok or not root or root == "" then
		root = vim.fn.getcwd()
	end
	return normalize(root)
end

-- Convert an absolute file path into the `/relative/path/without/extension`
-- form vimwiki links use.
local function to_link_path(abs_path, root)
	abs_path = normalize(abs_path)
	local rel
	if abs_path == root then
		rel = ""
	elseif abs_path:sub(1, #root + 1) == root .. "/" then
		rel = abs_path:sub(#root + 2)
	else
		rel = vim.fn.fnamemodify(abs_path, ":t")
	end
	rel = rel:gsub("%.[^./]+$", "")
	return rel
end

-- Insert `text` after the character under the cursor (matching normal-mode
-- 'p', not 'P') and leave the cursor on the last inserted character, still
-- in normal mode. Inserting *before* the cursor would land text ahead of
-- the character it's sitting on - e.g. on a line "- " with the cursor on
-- the trailing space (its only valid normal-mode position at end of line),
-- that would produce "-[[...]] " instead of the intended "- [[...]]".
local function insert_after_cursor(text)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local insert_col = #line > 0 and col + 1 or 0
	vim.api.nvim_buf_set_text(0, row - 1, insert_col, row - 1, insert_col, { text })
	vim.api.nvim_win_set_cursor(0, { row, insert_col + #text - 1 })
end

function M.insert_link()
	local root = wiki_root()
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	require("telescope.builtin").find_files({
		prompt_title = "Insert Wiki Link",
		cwd = root,
		attach_mappings = function(prompt_bufnr, _)
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if not entry then
					return
				end

				local link = string.format("[[/%s]]", to_link_path(entry.path or entry[1], root))
				vim.schedule(function()
					insert_after_cursor(link)
				end)
			end)
			return true
		end,
	})
end

return M
