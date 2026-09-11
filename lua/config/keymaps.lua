local map = vim.keymap.set

-- Training wheels: disable arrow keys in normal and insert mode
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
	map({ "n", "i" }, key, "<Nop>")
end

map("n", "Y", "y$")

-- Strip trailing whitespace, preserving the exact cursor position
map("n", "<Leader>s", function()
	local view = vim.fn.winsaveview()
	vim.cmd([[keeppatterns %s/\s\+$//e]])
	vim.cmd("nohlsearch")
	vim.fn.winrestview(view)
end, { silent = true, desc = "Strip trailing whitespace" })

map("n", "<Leader><Leader>", ":w<CR>", { silent = true, desc = "Save file" })
map("n", "<Leader>nh", ":nohl<CR>", { desc = "Clear search highlight" })

-- JSON prettifier (requires python on PATH)
map("v", "<leader>json", ":!python -m json.tool<CR>", { silent = true, desc = "Format JSON" })

-- SQL prettifier (requires `pip install sqlparse`)
map(
	"v",
	"<leader>sql",
	":!sqlformat --reindent --keywords upper --identifiers lower -<CR>",
	{ silent = true, desc = "Format SQL" }
)

map("n", "<Leader>bd", function()
	require("util.buffers").close_buffer()
end, { silent = true, desc = "Close buffer, keep window" })

map("n", "<Leader>bka", function()
	require("util.buffers").wipe_after_current()
end, { silent = true, desc = "Wipe buffers after current" })

-- Insert an 80-char '#' header line, e.g. for note section breaks
map("n", "<Leader>3", "080i#<Esc>a<CR># ", { desc = "Insert header line" })

map("n", "<Leader>lo", ":lopen<CR>", { silent = true, desc = "Open location list" })
map("n", "<Leader>lc", ":lclose<CR>", { silent = true, desc = "Close location list" })

-- Insert datetime stamp (useful for notes)
map("n", "<leader>dt", "\"=strftime('%c')<CR>gp", { desc = "Insert datetime stamp" })

-- Session load picker, backed by mini.sessions (lua/plugins/editor.lua)
-- (replaces vim-startify's <Leader>p -> :SLoad<Space>)
map("n", "<Leader>p", function()
	MiniSessions.select("read")
end, { desc = "Load session" })
