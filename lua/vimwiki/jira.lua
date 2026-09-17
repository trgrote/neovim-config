-- :NewJiraTicket <url> - fetch a Jira issue and create a ticket file from
-- it, linked from the current wiki page's '## Tickets' heading. Full Lua
-- port of ft#VimWikiHelpers#MakeTicketFromJira and its helpers.
--
-- Requires $JIRA_EMAIL and $JIRA_API_TOKEN in the environment:
--   1. Log into https://id.atlassian.com/manage-profile/security/api-tokens
--      and click "Create API token". Copy it immediately - it's only
--      shown once.
--   2. Export both in your shell profile (.bashrc/.zshrc/etc.):
--        export JIRA_EMAIL="you@example.com"
--        export JIRA_API_TOKEN="<token>"
--      then start a new shell (or `source` the profile) so Neovim
--      inherits the values.
local util = require("vimwiki.util")
local adf = require("vimwiki.adf")

local M = {}

-- Returns host, key - or nil, nil if the url doesn't look like a Jira
-- issue link (e.g. https://midwestlabs.atlassian.net/browse/SD-5619).
function M.parse_jira_url(url)
	local host, key = url:match("^https?://([^/]+)/browse/(%w+%-%d+)")
	if not key then
		return nil, nil
	end
	return host, key
end

-- Uses `curl -K -` (config read from stdin) so the URL/auth never show up
-- in a process listing or shell history.
function M.fetch_jira_issue(host, key)
	local email = vim.env.JIRA_EMAIL
	local token = vim.env.JIRA_API_TOKEN
	if not email or email == "" or not token or token == "" then
		vim.notify("NewJiraTicket: set $JIRA_EMAIL and $JIRA_API_TOKEN environment variables first.", vim.log.levels.WARN)
		return nil
	end

	local api_url = string.format("https://%s/rest/api/3/issue/%s?fields=summary,description", host, key)
	local curl_config = table.concat({
		'url = "' .. api_url .. '"',
		'header = "Accept: application/json"',
		'user = "' .. email .. ":" .. token .. '"',
	}, "\n") .. "\n"

	local result = vim.system({ "curl", "-s", "-K", "-" }, { stdin = curl_config, text = true }):wait(15000)
	if result.code ~= 0 then
		vim.notify("NewJiraTicket: curl failed to run (is curl installed and on PATH?).", vim.log.levels.WARN)
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, result.stdout)
	if not ok or type(decoded) ~= "table" then
		vim.notify("NewJiraTicket: could not parse the Jira response as JSON.", vim.log.levels.WARN)
		return nil
	end

	if decoded.errorMessages then
		vim.notify("NewJiraTicket: Jira error - " .. table.concat(decoded.errorMessages, "; "), vim.log.levels.WARN)
		return nil
	end

	return decoded
end

-- Reuses only the static "## Research / ## Development / ## Go Live" tail
-- of templates/skeleton.md (everything after the START_DATE placeholder),
-- so editing that boilerplate keeps both :NewTicket and :NewJiraTicket in
-- sync. The header/description part is built directly since its shape
-- differs from the plain-text skeleton, and Jira-sourced text can contain
-- characters that would break a substitute-based approach.
function M.build_jira_ticket_lines(key, summary, url, description_lines)
	local template = vim.fn.readfile(util.skeleton_path())
	local date_idx = nil
	for i, line in ipairs(template) do
		if line == "**START_DATE**" then
			date_idx = i
			break
		end
	end

	local boilerplate_tail = {}
	if date_idx then
		for i = date_idx + 1, #template do
			table.insert(boilerplate_tail, template[i])
		end
	end

	-- Built manually rather than via strftime flags: glibc uses '%-m' to
	-- suppress zero-padding while Windows/MSVC uses '%#m', so no single
	-- format string works on both.
	local now = os.date("*t")
	local hour12 = now.hour % 12
	if hour12 == 0 then
		hour12 = 12
	end
	local ampm = now.hour < 12 and "AM" or "PM"
	local creation_time = string.format(
		"%d/%d/%d %d:%02d:%02d %s",
		now.month,
		now.day,
		now.year,
		hour12,
		now.min,
		now.sec,
		ampm
	)

	local lines = {
		string.format("# %s: %s", key, summary),
		"",
		"## Description",
		string.format("- Creation Time: **%s**", creation_time),
		string.format("- %s", url),
	}
	if #description_lines > 0 then
		table.insert(lines, "")
		vim.list_extend(lines, description_lines)
	end
	vim.list_extend(lines, boilerplate_tail)
	return lines
end

-- :NewJiraTicket https://midwestlabs.atlassian.net/browse/SD-5619
function M.make_ticket_from_jira(url)
	local host, key = M.parse_jira_url(url)
	if not key then
		vim.notify("NewJiraTicket: could not find a Jira issue key in url: " .. url, vim.log.levels.WARN)
		return
	end

	local issue = M.fetch_jira_issue(host, key)
	if not issue then
		return
	end

	local fields = issue.fields or {}
	local summary = fields.summary or key
	local description_lines = adf.doc_to_lines_safe(fields.description or {})

	local ticket_folder = util.make_ticket_folder(key)
	local ticket_file = string.format("%s/%s.md", ticket_folder, key)
	local ticket_link_path = string.format("/%s/%s", ticket_folder, key)

	util.insert_ticket_link(key, summary, ticket_link_path)

	vim.fn.writefile(M.build_jira_ticket_lines(key, summary, url, description_lines), ticket_file)
	vim.cmd("edit ./" .. ticket_file)
end

return M
