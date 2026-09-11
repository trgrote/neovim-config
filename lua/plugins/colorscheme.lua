-- Lua-native monokai, replacing sickill/vim-monokai. The 'classic' palette
-- is the closest visual match to the original.
return {
	"tanvirtin/monokai.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("monokai").setup({ palette = require("monokai").classic })
		vim.cmd.colorscheme("monokai")

		-- Header colors from the original vimwiki config (stolen from
		-- http://www.eclipsecolorthemes.org/?view=theme&id=6093), reapplied on
		-- every colorscheme change since it overwrites highlight groups on load.
		local function set_vimwiki_headers()
			vim.api.nvim_set_hl(0, "VimwikiHeader1", { fg = "#F92672" })
			vim.api.nvim_set_hl(0, "VimwikiHeader2", { fg = "#AE81FF" })
			vim.api.nvim_set_hl(0, "VimwikiHeader3", { fg = "#A6E22E" })
			vim.api.nvim_set_hl(0, "VimwikiHeader4", { fg = "#66D9EF" })
			vim.api.nvim_set_hl(0, "VimwikiHeader5", { fg = "#FFE792" })
			vim.api.nvim_set_hl(0, "VimwikiHeader6", { fg = "#F8F8F2" })
		end
		set_vimwiki_headers()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("VimwikiHeaderColors", { clear = true }),
			callback = set_vimwiki_headers,
		})
	end,
}
