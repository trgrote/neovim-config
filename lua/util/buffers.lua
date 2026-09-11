local M = {}

-- Close the current buffer while keeping the window/split it lives in open
-- (replaces qpkorr/vim-bufkill's :BD, which the original config bound to
-- <Leader>bd). Switches to the alternate buffer if there is one, otherwise
-- the next listed buffer, otherwise a fresh empty buffer.
function M.close_buffer()
  local cur = vim.api.nvim_get_current_buf()
  local alt = vim.fn.bufnr("#")

  if alt ~= -1 and alt ~= cur and vim.api.nvim_buf_is_loaded(alt) and vim.fn.buflisted(alt) == 1 then
    vim.cmd("buffer " .. alt)
  else
    local listed = vim.tbl_filter(function(b)
      return b ~= cur and vim.fn.buflisted(b) == 1
    end, vim.api.nvim_list_bufs())

    if #listed > 0 then
      vim.cmd("buffer " .. listed[1])
    else
      vim.cmd("enew")
    end
  end

  if vim.api.nvim_buf_is_valid(cur) then
    pcall(vim.cmd, "bdelete! " .. cur)
  end
end

-- Wipe out every buffer numbered after the current one (replaces the
-- original's inline `:.+,$bwipeout`, bound to <Leader>bka).
function M.wipe_after_current()
  local cur = vim.fn.bufnr("%")
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b > cur then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
end

return M
