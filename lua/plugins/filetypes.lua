-- Standalone language ftplugins with no relation to any other spec file.
return {
	{
		"vim-perl/vim-perl",
		ft = "perl",
		build = "make clean carp dancer highlight-all-pragmas moose test-more try-tiny",
	},

	{ "PProvost/vim-ps1", ft = "ps1" },
}
