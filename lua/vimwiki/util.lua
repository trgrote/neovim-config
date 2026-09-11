-- Shared helpers for the vimwiki/* modules. Replaces the small local
-- helper functions at the top of autoload/ft/VimWikiHelpers.vim.
local M = {}

-- Replaces g:vimfiles_dir - this config's own root, used to resolve
-- templates/skeleton.md and templates/skeleton.diary.md.
function M.config_dir()
	return vim.fn.stdpath("config")
end

function M.skeleton_path()
	return M.config_dir() .. "/templates/skeleton.md"
end

-- Create the folder a ticket's file lives in (e.g. "Tickets/SD-5619").
function M.make_ticket_folder(ticket_id)
	local folder = string.format("Tickets/%s", ticket_id)
	vim.fn.mkdir(folder, "p")
	return folder
end

-- Find the current buffer's '## Tickets' heading and insert a new link
-- list item right after it, then save the buffer.
function M.insert_ticket_link(ticket_id, description, ticket_link_path)
	local heading_line = vim.fn.search("## Tickets")
	if heading_line == 0 then
		vim.notify("insert_ticket_link: no '## Tickets' heading found in current buffer.", vim.log.levels.WARN)
		return
	end

	local link = string.format("[%s: %s](%s)", ticket_id, description, ticket_link_path)
	-- Mirrors the original's `}O...`: jump to the end of the paragraph under
	-- the heading (the end of the existing link list, or the heading itself
	-- if the list is empty) and open a new line there.
	vim.cmd("normal! " .. heading_line .. "G}")
	local insert_after = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, insert_after, insert_after, false, { "- " .. link })
	vim.cmd("write")
end

-- Literal (non-pattern) text substitution of every occurrence, on every
-- line, in the current buffer (mirrors :%s/pattern/replacement/g but as a
-- plain string match). Deliberately not vim.fn.substitute()/gsub() with a
-- "magic" replacement string: replacement text (Jira summaries, user-typed
-- descriptions) can contain literal '%' bytes that gsub's replacement
-- argument would otherwise misinterpret.
function M.replace_in_buffer(pattern, replacement)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for i, line in ipairs(lines) do
		local parts = {}
		local pos = 1
		while true do
			local start_idx, end_idx = line:find(pattern, pos, true)
			if not start_idx then
				table.insert(parts, line:sub(pos))
				break
			end
			table.insert(parts, line:sub(pos, start_idx - 1))
			table.insert(parts, replacement)
			pos = end_idx + 1
		end
		lines[i] = table.concat(parts)
	end
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

return M
