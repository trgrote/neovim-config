-- In-memory named marks: jump back to a cursor location by name via
-- Telescope. Deliberately has no concept of sessions or persistence - that
-- coupling lives in lua/plugins/session.lua, which imports/exports/clears
-- this module's table around auto-session's save/restore hooks.
local M = {}

M.marks = {}

function M.set(name)
	if name then
		local file = vim.api.nvim_buf_get_name(0)
		if file == "" then
			vim.notify("named-marks: can't mark an unnamed buffer", vim.log.levels.WARN)
			return
		end
		local cursor = vim.api.nvim_win_get_cursor(0)
		M.marks[name] = { file = file, lnum = cursor[1], col = cursor[2] }
		return
	end

	vim.ui.input({
		prompt = "Named mark: ",
		-- Tab-completes existing names, so overwriting one (e.g. moving
		-- "unit test" to a new location) doesn't require retyping it -
		-- and reduces typo'd near-duplicates cluttering the mark list.
		completion = "customlist,v:lua.require'util.named-marks'.complete_names",
	}, function(input)
		if input and input ~= "" then
			M.set(input)
		end
	end)
end

--- input() "customlist" completion function - Vim does no filtering of its
--- own for customlist, so this must only return names matching arg_lead.
function M.complete_names(arg_lead)
	local matches = {}
	for name in pairs(M.marks) do
		if vim.startswith(name, arg_lead) then
			table.insert(matches, name)
		end
	end
	table.sort(matches)
	return matches
end

function M.remove(name)
	M.marks[name] = nil
end

function M.clear()
	M.marks = {}
end

function M.goto(name)
	local mark = M.marks[name]
	if not mark then
		return
	end
	vim.cmd.edit(mark.file)
	local lnum = math.min(mark.lnum, vim.api.nvim_buf_line_count(0))
	vim.api.nvim_win_set_cursor(0, { lnum, mark.col })
end

function M.export()
	return M.marks
end

function M.import(tbl)
	M.marks = tbl or {}
end

function M.picker()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local function entries()
		local results = {}
		for name, mark in pairs(M.marks) do
			table.insert(results, { name = name, mark = mark })
		end
		table.sort(results, function(a, b)
			return a.name < b.name
		end)
		return results
	end

	pickers
		.new({}, {
			prompt_title = "Named Marks",
			finder = finders.new_table({
				results = entries(),
				entry_maker = function(entry)
					local display = string.format("%s  %s:%d", entry.name, vim.fn.fnamemodify(entry.mark.file, ":."), entry.mark.lnum)
					return {
						value = entry.name,
						display = display,
						ordinal = display,
						path = entry.mark.file,
						lnum = entry.mark.lnum,
						col = entry.mark.col + 1,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = conf.grep_previewer({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						M.goto(selection.value)
					end
				end)

				map({ "i", "n" }, "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if not selection then
						return
					end
					M.remove(selection.value)
					local picker = action_state.get_current_picker(prompt_bufnr)
					picker:refresh(
						finders.new_table({
							results = entries(),
							entry_maker = picker.finder.entry_maker,
						}),
						{ reset_prompt = false }
					)
				end)

				return true
			end,
		})
		:find()
end

return M
