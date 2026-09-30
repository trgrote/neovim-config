local M = {}

-- Treesitter node types that make up a method chain, mapped to the field that
-- holds the receiver (the thing to the left of the `.`). Covers JS/TS/TSX,
-- C# and Lua; the type names do not overlap so one table serves all of them.
local MEMBER = {
	member_expression = "object",
	member_access_expression = "expression",
	dot_index_expression = "table",
	method_index_expression = "table",
}

local CALL = {
	call_expression = "function",
	invocation_expression = "function",
	function_call = "name",
}

local function is_link(node)
	return MEMBER[node:type()] ~= nil or CALL[node:type()] ~= nil
end

-- Nearest chain node at or above the cursor, then the outermost chain node
-- containing it.
local function find_chain_root()
	local parsed, parser = pcall(vim.treesitter.get_parser, 0)
	if parsed and parser then
		parser:parse()
	end

	local ok, node = pcall(vim.treesitter.get_node)
	if not ok or not node then
		return nil
	end

	while node and not is_link(node) do
		node = node:parent()
	end
	if not node then
		return nil
	end

	local parent = node:parent()
	while parent and is_link(parent) do
		node = parent
		parent = node:parent()
	end
	return node
end

-- Walk the receiver side of the chain from the innermost node outwards.
-- Each entry describes one `.` (or `:`/`?.`) operator: where it starts, where
-- the receiver to its left ends, and whether a call appears to its left.
local function collect_ops(node, ops, state)
	local type = node:type()

	if CALL[type] then
		local target = node:field(CALL[type])[1]
		if target then
			collect_ops(target, ops, state)
		end
		state.seen_call = true
	elseif MEMBER[type] then
		local receiver = node:field(MEMBER[type])[1]
		if not receiver then
			return
		end
		collect_ops(receiver, ops, state)

		for child in node:iter_children() do
			if not child:named() then
				local sr, sc = child:range()
				local er, ec = receiver:end_()
				local _, _, pr, pc = child:range()
				table.insert(ops, {
					op_row = sr,
					op_col = sc,
					op_end_row = pr,
					op_end_col = pc,
					recv_end_row = er,
					recv_end_col = ec,
					after_call = state.seen_call,
				})
				break
			end
		end
	end
end

local function indent_unit()
	if vim.bo.expandtab then
		return string.rep(" ", vim.fn.shiftwidth())
	end
	return "\t"
end

local function gap_is_blank(row, col_start, end_row, end_col)
	local text = vim.api.nvim_buf_get_text(0, row, col_start, end_row, end_col, {})
	return table.concat(text, ""):match("^%s*$") ~= nil
end

-- Toggle the method chain under the cursor between one line and one
-- `.call()` per line. Only the root receiver (e.g. `_db`) stays on the first
-- line; a break goes before every `.`.
function M.toggle()
	local root = find_chain_root()
	if not root then
		vim.notify("No method chain under cursor", vim.log.levels.INFO)
		return
	end

	local ops = {}
	local state = { seen_call = false }
	collect_ops(root, ops, state)

	if #ops < 2 or not state.seen_call then
		vim.notify("Chain is too short to split", vim.log.levels.INFO)
		return
	end

	local is_multiline = false
	for _, o in ipairs(ops) do
		if o.op_row > o.recv_end_row then
			is_multiline = true
			break
		end
	end

	local edits = {}
	if is_multiline then
		-- Join: every operator that sits on a later line than its receiver.
		-- The blank check keeps comments between links from being deleted.
		for _, o in ipairs(ops) do
			if o.op_row > o.recv_end_row then
				if not gap_is_blank(o.recv_end_row, o.recv_end_col, o.op_row, o.op_col) then
					vim.notify("Comment inside chain, not joining", vim.log.levels.WARN)
					return
				end
				table.insert(edits, {
					o.recv_end_row,
					o.recv_end_col,
					o.op_row,
					o.op_col,
					"",
				})
			end
		end
	else
		local start_row = root:range()
		local base = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]:match("^%s*")
		local indent = "\n" .. base .. indent_unit()
		for _, o in ipairs(ops) do
			table.insert(edits, { o.recv_end_row, o.recv_end_col, o.op_row, o.op_col, indent })
		end
	end

	-- Apply bottom-up so earlier positions stay valid.
	table.sort(edits, function(a, b)
		if a[1] ~= b[1] then
			return a[1] > b[1]
		end
		return a[2] > b[2]
	end)
	for _, e in ipairs(edits) do
		vim.api.nvim_buf_set_text(0, e[1], e[2], e[3], e[4], vim.split(e[5], "\n", { plain = true }))
	end
end

return M
