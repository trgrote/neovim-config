-- Convert a range of '- ' unordered list lines into a numbered list,
-- preserving indentation. Full Lua port of
-- ft#VimWikiHelpers#ConvertToNumberedList: tracks a stack of
-- {indent, counter} pairs so each new nested block (deeper indentation)
-- restarts its numbering at 1, rather than a single running counter.
local M = {}

function M.convert_to_numbered_list(start_line, end_line)
	local stack = {}
	for lnum = start_line, end_line do
		local indent, rest = vim.fn.getline(lnum):match("^(%s*)%-%s+(.*)$")
		if indent then
			while #stack > 0 and #stack[#stack].indent > #indent do
				table.remove(stack)
			end

			if #stack > 0 and stack[#stack].indent == indent then
				stack[#stack].counter = stack[#stack].counter + 1
			else
				table.insert(stack, { indent = indent, counter = 1 })
			end

			vim.fn.setline(lnum, indent .. stack[#stack].counter .. ". " .. rest)
		end
	end
end

return M
