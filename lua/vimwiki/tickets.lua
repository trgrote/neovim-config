-- :NewTicket - create a new ticket file/folder and link it from the
-- current wiki page's '## Tickets' heading. Full Lua port of
-- ft#VimWikiHelpers#MakeTicketWithDesc.
local util = require("vimwiki.util")

local M = {}

-- ticket_id, then one or more description word tokens (mirrors the
-- original's -nargs=+ :NewTicket command).
function M.new_ticket(ticket_id, ...)
	local description_tokens = {}
	for _, token in ipairs({ ... }) do
		-- Strip '#', '/', and '-' from each token (the original's character
		-- class is "[#/-]", not just "#"/"-" despite what the surrounding
		-- comments say - preserved verbatim here).
		local stripped = token:gsub("[#/%-]", "")
		if stripped ~= "" then
			table.insert(description_tokens, stripped)
		end
	end
	local description = table.concat(description_tokens, " ")

	local ticket_folder = util.make_ticket_folder(ticket_id)
	local ticket_file = string.format("%s/%s.md", ticket_folder, ticket_id)
	local ticket_link_path = string.format("/%s/%s", ticket_folder, ticket_id)

	util.insert_ticket_link(ticket_id, description, ticket_link_path)

	-- Creating this new *.md file triggers the wiki_templates BufNewFile
	-- autocmd (lua/plugins/wiki.lua), which populates it from skeleton.md.
	vim.cmd("edit ./" .. ticket_file)

	local title = string.format("%s: %s", ticket_id, description)
	util.replace_in_buffer("TITLE", title)
	util.replace_in_buffer("START_DATE", os.date("%c"))
	vim.cmd("write")
end

return M
