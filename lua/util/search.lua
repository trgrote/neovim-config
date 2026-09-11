local M = {}

-- Recursive lvimgrep search, opening the location list window. Wraps
-- lvimgrep with a friendlier interface: a bare pattern is treated as a
-- literal search and escaped/wrapped in slashes; anything already starting
-- with '/' is passed straight through.
function M.search(search_pattern)
  if search_pattern == "" then
    vim.notify("No search pattern given.", vim.log.levels.INFO)
    return
  end

  local pattern = search_pattern
  if not vim.startswith(pattern, "/") then
    pattern = "/" .. vim.fn.escape(pattern, "\\") .. "/"
  end

  local path = vim.fn.fnameescape(vim.fn.getcwd())

  -- Include the 'j' flag so we don't jump to the first match: without it,
  -- the first matching file would open with noautocmd still in effect,
  -- which would skip syntax highlighting.
  local cmd = "noautocmd lvimgrep " .. pattern .. "j " .. path .. "**"

  local ok = pcall(vim.cmd, cmd)
  if ok then
    vim.cmd("lopen")
  else
    vim.notify("Search: No match found.", vim.log.levels.INFO)
  end
end

return M
