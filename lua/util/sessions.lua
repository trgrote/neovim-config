-- Small session save/load, replacing vim-startify's session persistence
-- (startify_session_persistence, startify_session_delete_buffers,
-- startify_session_before_save) without pulling in a dedicated plugin.
local M = {}

local function session_dir()
  local dir = vim.fn.stdpath("state") .. "/sessions"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function default_session_name()
  return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function session_path(name)
  name = (name and name ~= "") and name or default_session_name()
  return session_dir() .. "/" .. name .. ".vim"
end

function M.save(name)
  pcall(vim.cmd, "silent! tabdo NvimTreeClose")
  vim.cmd("mksession! " .. vim.fn.fnameescape(session_path(name)))
end

-- Wipes currently open buffers before loading, mirroring
-- startify_session_delete_buffers=1.
function M.load(name)
  local path = session_path(name)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("No session found: " .. path, vim.log.levels.WARN)
    return
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  vim.cmd("source " .. vim.fn.fnameescape(path))
end

-- Replaces the original's <Leader>p -> :SLoad<Space> (prompt for a session
-- name, defaulting to the current directory's name).
function M.prompt_load()
  vim.ui.input({ prompt = "Session name (blank = " .. default_session_name() .. "): " }, function(input)
    if input == nil then
      return
    end
    M.load(input)
  end)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("SessionAutosave", { clear = true }),
  callback = function()
    M.save()
  end,
})

return M
