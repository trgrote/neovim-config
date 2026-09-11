-- Diary automation: carry forward the previous day's incomplete TODOs into
-- a newly created diary entry, and regenerate the diary index. Full Lua
-- port of s:GetPreviousTODOS/ft#VimWikiHelpers#AppendPreviousTODO/
-- ft#VimWikiHelpers#UpdateDiaryIndex from autoload/ft/VimWikiHelpers.vim.
local M = {}

local function index_of(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

function M.get_previous_todos(current_day_filename)
	local diary_dir = vim.fn.expand(vim.g.calendar_diary)
	local diary_files = vim.fn.readdir(diary_dir, function(name)
		return name:match("^%d%d%d%d%-%d%d%-%d%d%.md$") ~= nil
	end)
	local default_return = { "- [ ] " }

	-- Insert the current day's file (which doesn't exist yet) so the list
	-- can be split between previous days and future days.
	local appended = vim.deepcopy(diary_files)
	table.insert(appended, current_day_filename)
	table.sort(appended)

	-- Dedupe adjacent duplicates (mirrors vim's uniq() on an already-sorted
	-- list).
	local deduped = {}
	for _, v in ipairs(appended) do
		if deduped[#deduped] ~= v then
			table.insert(deduped, v)
		end
	end
	appended = deduped

	local current_idx = index_of(appended, current_day_filename)
	if not current_idx then
		return default_return
	end

	local previous_diaries = {}
	for i = 1, current_idx - 1 do
		table.insert(previous_diaries, appended[i])
	end

	if #previous_diaries == 0 then
		return default_return
	end

	local previous_diary = previous_diaries[#previous_diaries]
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

function M.append_previous_todo(file_name)
	local prev_lines = M.get_previous_todos(file_name)
	vim.api.nvim_buf_set_lines(0, -1, -1, false, prev_lines)
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
