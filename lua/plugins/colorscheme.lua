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
		-- Misspelled words keep the red squiggly underline but not the red
		-- font color the colorscheme gives them.
		local function set_spell_highlights()
			local bad = vim.api.nvim_get_hl(0, { name = "SpellBad", link = false })
			bad.fg = nil
			bad.ctermfg = nil
			bad.undercurl = true
			bad.sp = bad.sp or bad.special or "#F92672"
			vim.api.nvim_set_hl(0, "SpellBad", bad)
		end

		local function apply_custom_highlights()
			set_vimwiki_headers()
			set_spell_highlights()
		end
		apply_custom_highlights()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("VimwikiHeaderColors", { clear = true }),
			callback = apply_custom_highlights,
		})
	end,
}
