-- C#-specific config.

-- Fold using Roslyn's folding ranges (#region blocks, classes, methods,
-- usings, etc.), overriding the global marker foldmethod
-- (lua/config/options.lua) for C# buffers only. Folds appear once roslyn
-- has attached and loaded the solution.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.lsp.foldexpr()"
-- Start with everything unfolded so jumping to a line (e.g. from a grep)
-- never lands inside a closed fold. Use zM / zm to fold on demand.
vim.opt_local.foldlevel = 99

-- Typing a third "/" on an otherwise empty comment line expands a Visual
-- Studio style XML doc summary block with the cursor inside it. Uses the
-- built-in vim.snippet, so <Tab> / <S-Tab> (blink.cmp default keymap) jump
-- between tabstops. Anywhere else "/" types normally.
vim.keymap.set("i", "/", function()
	local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1)
	if not before:match("^%s*//$") then
		return "/"
	end
	-- Can't call vim.snippet.expand while inside an <expr> mapping, so defer.
	vim.schedule(function()
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		vim.api.nvim_buf_set_text(0, row - 1, col - 2, row - 1, col, {})
		vim.snippet.expand("/// <summary>\n/// $0\n/// </summary>")
	end)
	return ""
end, { buffer = true, expr = true, desc = "Expand XML doc summary on ///" })
