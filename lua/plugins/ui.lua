return {
	-- Statusline, replacing vim-airline(+themes). 'auto' derives colors from
	-- the active colorscheme's highlight groups, which pairs correctly with
	-- monokai.nvim without betting on a bundled lualine theme matching it.
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			options = { theme = "auto", globalstatus = true },
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch" },
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			-- Buffer list at the top, replacing
			-- airline#extensions#tabline#enabled = 1.
			tabline = {
				lualine_a = {
					{
						"buffers",
						symbols = {
							alternate_file = "", -- hide the '#' alternate-buffer marker
						},
						buffers_color = {
							inactive = "lualine_c_inactive",
						},
					},
				},
				lualine_z = { "tabs" },
			},
		},
	},

	-- Dashboard, replacing mhinz/vim-startify. Header is centered
	-- automatically by alpha, unlike the original's manual s:filter_header().
	{
		"goolord/alpha-nvim",
		event = "VimEnter",
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")

			dashboard.section.header.val = {
				"                                                ",
				"                  @@@@@@ @                      ",
				"                 @@@@     @@                    ",
				"                @@@@ =   =  @@                  ",
				"               @@@ @ _   _   @@                 ",
				"               @@@ @(0)|(0)  @@                 ",
				"              @@@@   ~ | ~   @@                 ",
				"              @@@ @  (o1o)    @@                ",
				"             @@@    #######    @                ",
				"             @@@   ##{+++}##   @@               ",
				"            @@@@@ ## ##### ## @@@@              ",
				"            @@@@@#############@@@@              ",
				"           @@@@@@@###########@@@@@@             ",
				"          @@@@@@@#############@@@@@             ",
				"          @@@@@@@### ## ### ###@@@@             ",
				"           @ @  @              @  @             ",
				"             @                    @             ",
				"                                                ",
				"Me Mo Mo Richard Stallman, Welcome to the EMACS!",
				"",
			}

			dashboard.section.buttons.val = {
				dashboard.button("p", "  Open session", ":AutoSession search<CR>"),
				dashboard.button("e", "  New file", ":enew<CR>"),
				dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
				dashboard.button("q", "  Quit", ":qa<CR>"),
			}

			alpha.setup(dashboard.opts)
		end,
	},
}
