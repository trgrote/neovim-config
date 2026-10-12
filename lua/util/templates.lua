-- Path-based file templates: a new file is populated from the first
-- matching rule in <cwd>/.templates/rules.json, then the global
-- templates/rules.json. See "File templates" in README.md for the rules
-- schema, hooks.lua and placeholders.
local M = {}

local is_win = vim.fn.has("win32") == 1

M.local_dir_name = ".templates"

function M.global_dir()
	return vim.fn.stdpath("config") .. "/templates"
end

function M.local_dir()
	return vim.fs.normalize(vim.fn.getcwd()) .. "/" .. M.local_dir_name
end

local function normalize(path)
	return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

-- Windows paths are case-insensitive, so compare/match them lowercased.
local function fold(s)
	return is_win and s:lower() or s
end

local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

local function warn(msg)
	vim.notify(msg, vim.log.levels.WARN)
end

-- Load <dir>/rules.json, dropping (and warning about) malformed rules.
local function load_rules(dir)
	local path = dir .. "/rules.json"
	if not exists(path) then
		return nil
	end

	local ok, config = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
	if not ok then
		warn(path .. " failed to parse: " .. tostring(config))
		return nil
	elseif type(config) ~= "table" then
		warn(path .. " must contain a JSON object")
		return nil
	end

	local rules = {}
	for i, rule in ipairs(type(config.rules) == "table" and config.rules or {}) do
		local valid = type(rule) == "table"
			and type(rule.pattern) == "string"
			and (type(rule.template) == "string" or rule.template == false)
			and (rule.vars == nil or type(rule.vars) == "table")
			and (rule.post == nil or type(rule.post) == "string")
		if valid then
			table.insert(rules, rule)
		else
			warn(string.format("%s: ignoring invalid rule #%d", path, i))
		end
	end
	return { dir = dir, inherit = config.inherit, rules = rules }
end

-- Load the trusted global hooks.lua ({ vars = {...}, post = {...} }).
local function load_hooks()
	local path = M.global_dir() .. "/hooks.lua"
	local empty = { vars = {}, post = {} }
	if not exists(path) then
		return empty
	end

	local chunk, err = loadfile(path)
	local ok, hooks = false, err
	if chunk then
		ok, hooks = pcall(chunk)
	end
	if not ok then
		warn(path .. " failed to load: " .. tostring(hooks))
		return empty
	elseif type(hooks) ~= "table" then
		warn(path .. " must return a table, got " .. type(hooks))
		return empty
	end
	hooks.vars = hooks.vars or {}
	hooks.post = hooks.post or {}
	return hooks
end

-- Returns the first matching rule and its ctx, or nil.
function M.find_rule(file, buf)
	file = normalize(file)
	local cwd = vim.fs.normalize(vim.fn.getcwd())

	local rel = nil
	if fold(file):sub(1, #cwd + 1) == fold(cwd) .. "/" then
		rel = file:sub(#cwd + 2)
	end

	local scopes = {}
	-- Files outside cwd never match local rules.
	local local_config = rel and load_rules(M.local_dir())
	if local_config then
		table.insert(scopes, { config = local_config, path = rel })
	end
	if not (local_config and local_config.inherit == false) then
		local global_config = load_rules(M.global_dir())
		if global_config then
			table.insert(scopes, { config = global_config, path = file })
		end
	end

	for _, scope in ipairs(scopes) do
		for _, rule in ipairs(scope.config.rules) do
			if vim.glob.to_lpeg(fold(rule.pattern)):match(fold(scope.path)) then
				return rule, { buf = buf, file = file, rel = rel, cwd = cwd, root = scope.config.dir, rule = rule }
			end
		end
	end
	return nil
end

-- Resolve a template name in the owning folder, falling back to the
-- global one.
local function resolve_template(name, root)
	for _, dir in ipairs({ root, M.global_dir() }) do
		local path = dir and (dir .. "/" .. name)
		if path and exists(path) then
			return path
		end
	end
	return nil
end

-- Read a template and substitute its placeholders. Precedence: rule vars,
-- then hooks.lua vars, then the built-ins. Returns the lines and the
-- {{cursor}} position ({ row, col }, 1-based row / 0-based col) or nil.
function M.render(template_path, ctx, hooks)
	local values = {
		title = vim.fn.fnamemodify(ctx.file, ":t:r"),
		date = os.date("%Y-%m-%d"),
		datetime = os.date("%c"),
		cwd = ctx.cwd,
	}
	for _, vars in ipairs({ hooks.vars, ctx.rule.vars or {} }) do
		for name, value in pairs(vars) do
			values[name] = value
		end
	end

	local lines = {}
	for _, template_line in ipairs(vim.fn.readfile(template_path)) do
		-- A function replacement is used literally, so '%' in values is safe.
		-- Unknown placeholders (and {{cursor}}) are left as-is.
		local rendered = template_line:gsub("{{([%w_]+)}}", function(name)
			local value = name ~= "cursor" and values[name] or nil
			if type(value) == "function" then
				value = value(ctx)
			end
			return value ~= nil and tostring(value) or nil
		end)
		-- Multi-line values become separate buffer lines.
		vim.list_extend(lines, vim.split(rendered, "\n", { plain = true }))
	end

	-- Located after splitting, so {{cursor}} following a multi-line value
	-- lands on that value's last line.
	local cursor = nil
	for i, line in ipairs(lines) do
		local cursor_start, cursor_end = line:find("{{cursor}}", 1, true)
		if cursor_start then
			if not cursor then
				cursor = { i, cursor_start - 1 }
			end
			lines[i] = line:sub(1, cursor_start - 1) .. line:sub(cursor_end + 1)
		end
	end
	return lines, cursor
end

local function apply(buf, template_path, ctx)
	local hooks = load_hooks()
	local lines, cursor = M.render(template_path, ctx, hooks)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	if buf == vim.api.nvim_get_current_buf() then
		if not cursor then
			local last = vim.api.nvim_buf_line_count(buf)
			cursor = { last, #(lines[last] or "") }
		end
		vim.api.nvim_win_set_cursor(0, cursor)
	end

	local post_name = ctx.rule.post
	if post_name then
		local post = hooks.post[post_name]
		if type(post) == "function" then
			post(ctx)
		else
			warn("Template: no post hook named '" .. post_name .. "' in hooks.lua")
		end
	end
end

local function buf_is_empty(buf)
	return vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

-- The matching ctx (with ctx.rule) and resolved template path for a file,
-- or nil.
local function template_for(file, buf)
	local rule, ctx = M.find_rule(file, buf)
	-- `template = false` matches (stopping the search) but leaves the
	-- file empty.
	if not rule or not ctx or rule.template == false then
		return nil
	end

	local template_path = resolve_template(rule.template, ctx.root)
	if not template_path then
		warn("Template not found: " .. tostring(rule.template))
		return nil
	end
	return ctx, template_path
end

function M.on_new_file(args)
	local buf = args.buf
	if vim.bo[buf].buftype ~= "" or not buf_is_empty(buf) then
		return
	end

	local ctx, template_path = template_for(args.file, buf)
	if ctx then
		apply(buf, template_path, ctx)
	end
end

-- Fill an existing, empty file on disk from its matching template, for
-- files created outside a buffer (e.g. by a file explorer). There's no
-- buffer, so {{cursor}} is just dropped and `post` doesn't run.
function M.fill_file(path)
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= "file" or stat.size > 0 then
		return
	end
	-- Leave it alone if it's already open in a buffer.
	local buf = vim.fn.bufnr(path)
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		return
	end

	local ctx, template_path = template_for(path, nil)
	if ctx then
		local lines = M.render(template_path, ctx, load_hooks())
		vim.fn.writefile(lines, path)
	end
end

-- Apply a template by name to the current buffer (local folder first, then
-- global). No rule is involved, so only built-in and hooks.lua vars are
-- substituted and no `post` runs. Refuses to overwrite a non-empty buffer
-- unless `force`.
function M.apply_by_name(name, force)
	local buf = vim.api.nvim_get_current_buf()
	if not force and not buf_is_empty(buf) then
		warn("Template: buffer is not empty (use :Template! to replace it)")
		return
	end

	local local_dir = M.local_dir()
	local template_path = resolve_template(name, local_dir)
	if not template_path then
		warn("Template not found: " .. name)
		return
	end

	apply(buf, template_path, {
		buf = buf,
		file = normalize(vim.api.nvim_buf_get_name(buf)),
		cwd = vim.fs.normalize(vim.fn.getcwd()),
		root = local_dir,
		rule = {},
	})
end

-- Template file names available from cwd (local and global), for completion.
function M.template_names()
	local skip = { ["rules.json"] = true, ["hooks.lua"] = true }
	local seen, names = {}, {}
	for _, dir in ipairs({ M.local_dir(), M.global_dir() }) do
		if exists(dir) then
			for name, type in vim.fs.dir(dir) do
				if type == "file" and not skip[name] and not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names)
	return names
end

return M
