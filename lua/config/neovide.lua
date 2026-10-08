-- Settings that only apply when running under Neovide (the standalone GUI
-- client) - a no-op when nvim is run in a terminal, since vim.g.neovide is
-- only set by Neovide itself.
if not vim.g.neovide then
	return
end

vim.o.guifont = "JetBrainsMonoNL NF:h16"

-- Disable animation/effects Neovide adds on top of plain Neovim
vim.g.neovide_scroll_animation_length = 0
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_short_animation_length = 0
vim.g.neovide_cursor_vfx_mode = ""
vim.g.neovide_progress_bar_enabled = false

-- Neovide has no terminal to translate Shift-Insert into a paste, so map it
vim.keymap.set({ "i", "c" }, "<S-Insert>", "<C-r>+", { desc = "Paste from system clipboard" })
vim.keymap.set("t", "<S-Insert>", '<C-\\><C-n>"+pi', { desc = "Paste from system clipboard" })
