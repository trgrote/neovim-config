-- Vimwiki filetype config. Full Lua port of ftplugin/vimwiki.vim.
vim.opt_local.spell = true

vim.api.nvim_create_user_command("NewTicket", function(opts)
  require("vimwiki.tickets").new_ticket(opts.fargs[1], unpack(opts.fargs, 2))
end, { buffer = true, nargs = "+" })

vim.api.nvim_create_user_command("NewJiraTicket", function(opts)
  require("vimwiki.jira").make_ticket_from_jira(opts.args)
end, { buffer = true, nargs = 1 })

-- Convert a visually selected block of '- ' unordered list items into a
-- numbered list.
vim.api.nvim_create_user_command("ConvertToNumberedList", function(opts)
  require("vimwiki.lists").convert_to_numbered_list(opts.line1, opts.line2)
end, { buffer = true, range = true })

-- Insert a datetime stamp surrounded by ** at the cursor.
vim.keymap.set("n", "<Leader>ts", "i**<C-R>=strftime('%c')<CR>**<Esc>", { buffer = true, silent = true })
-- Insert an ISO date at the cursor.
vim.keymap.set("n", "<Leader>date", "a<C-R>=strftime('%F')<CR><Esc>", { buffer = true, silent = true })

-- Surround a motion/text-object (or visual selection) in a markdown
-- wrapper, backed by lua/vimwiki/surround.lua.
local function opfunc_map(lhs, global_name)
  vim.keymap.set("n", lhs, function()
    vim.o.operatorfunc = "v:lua." .. global_name
    return "g@"
  end, { buffer = true, expr = true, silent = true })
end

opfunc_map("<Leader>fb", "__vimwiki_surround_bold") -- e.g. <Leader>fbiw wraps in '**'
opfunc_map("<Leader>fi", "__vimwiki_surround_italic") -- e.g. <Leader>fiiw wraps in '*'
opfunc_map("<Leader>fs", "__vimwiki_surround_strikethrough") -- e.g. <Leader>fsiw wraps in '~~'

vim.keymap.set("v", "<Leader>fb", function()
  require("vimwiki.surround").surround_bold("v")
end, { buffer = true, silent = true })
vim.keymap.set("v", "<Leader>fi", function()
  require("vimwiki.surround").surround_italic("v")
end, { buffer = true, silent = true })
vim.keymap.set("v", "<Leader>fs", function()
  require("vimwiki.surround").surround_strikethrough("v")
end, { buffer = true, silent = true })

vim.api.nvim_create_user_command("CalendarClose", function()
  vim.cmd("bwipeout! __Calendar")
end, {})

vim.opt.foldlevelstart = 2

-- Replace quotes/dashes that Jira sometimes pastes in and that would
-- otherwise crash the gollum wiki renderer: curly quotes, the mojibake
-- double-encoded single quotes Jira occasionally produces (U+0091/U+0092,
-- a Windows-1252-as-Latin-1 corruption of the real curly single quotes),
-- and em dashes. Each is a separate whole-string gsub (never combined
-- into one Lua pattern character class) so multi-byte UTF-8 sequences are
-- matched atomically rather than byte-by-byte.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("replacequotesgroup", { clear = true }),
  pattern = "*.md",
  callback = function(args)
    local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
    for i, line in ipairs(lines) do
      line = line:gsub("‘", "'"):gsub("’", "'")
      line = line:gsub("“", '"'):gsub("”", '"')
      line = line:gsub("\194\145", "'"):gsub("\194\146", "'") -- mojibake U+0091/U+0092
      line = line:gsub("—", "-")
      lines[i] = line
    end
    vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
  end,
})
