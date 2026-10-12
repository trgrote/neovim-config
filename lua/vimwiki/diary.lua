-- Diary helpers: collect the previous entry's incomplete TODOs, and
-- regenerate the diary index.
local M = {}

local function index_of(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

-- Incomplete TODOs from the most recent diary entry dated before
-- `current_day_path` (a YYYY-MM-DD.md file), found among its sibling
-- files - so it works wherever the diary lives, without vimwiki's paths.
function M.get_previous_todos(current_day_path)
	local diary_dir = vim.fn.fnamemodify(current_day_path, ":h")
	local current_day_filename = vim.fn.fnamemodify(current_day_path, ":t")
	local default_return = { "- [ ] " }

	-- ISO dates sort lexically, so the previous entry is the greatest
	-- sibling name that's less than the current one.
	local previous_diary = nil
	for name, type in vim.fs.dir(diary_dir) do
		if
			type == "file"
			and name:match("^%d%d%d%d%-%d%d%-%d%d%.md$")
			and name < current_day_filename
			and (not previous_diary or name > previous_diary)
		then
			previous_diary = name
		end
	end

	if not previous_diary then
		return default_return
	end

	local content = vim.fn.readfile(diary_dir .. "/" .. previous_diary)

	local todo_start = index_of(content, "## TODO")
	if not todo_start or todo_start >= #content then
		return default_return
	end

	-- Isolate the TODO section: everything after "## TODO" up to (but not
	-- including) the next "## " heading, or the end of the file.
	local todo_end_exclusive = #content + 1
	for i = todo_start + 1, #content do
		if content[i]:match("^## ") then
			todo_end_exclusive = i
			break
		end
	end

	-- Only keep incomplete checkboxes, resetting each to a bare "- [ ]".
	local filtered = {}
	for i = todo_start + 1, todo_end_exclusive - 1 do
		local line = content[i]
		if line:match("%- %[[^X]%]") then
			table.insert(filtered, (line:gsub("%- %[[^X]%]", "- [ ]", 1)))
		end
	end

	if #filtered == 0 then
		return default_return
	end

	for _, l in ipairs(default_return) do
		table.insert(filtered, l)
	end
	return filtered
end

-- Regenerate the vimwiki diary index (diary.md) so it links the current
-- buffer's diary entry, then save and close the index without disturbing
-- the calling window. Must be called from within a diary entry buffer,
-- since the entry has to exist on disk for VimwikiDiaryGenerateLinks'
-- file scan to pick it up.
function M.update_diary_index()
	vim.cmd("silent update")
	vim.cmd("split")
	vim.cmd("silent VimwikiDiaryIndex")
	vim.cmd("VimwikiDiaryGenerateLinks")
	vim.cmd("silent write")
	local diary_bufnr = vim.fn.bufnr("%")
	vim.cmd("close")
	vim.cmd("bwipeout " .. diary_bufnr)
end

return M
