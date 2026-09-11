-- Open a new file in the same directory as the current file
vim.api.nvim_create_user_command("NewFile", function(opts)
  vim.cmd("edit " .. vim.fn.expand("%:h") .. "/" .. opts.args)
end, { nargs = 1 })

-- Friendly recursive grep search (see lua/util/search.lua)
vim.api.nvim_create_user_command("Search", function(opts)
  require("util.search").search(opts.args)
end, { nargs = "*" })
