-- Surround a motion/text-object (or visual selection) in a markdown
-- wrapper string. Full port of autoload/ft/VimWikiHelpers.vim's
-- s:DoSurround opfunc pattern: yank the target range into the unnamed
-- register, wrap it, paste it back, and restore both 'selection' and the
-- unnamed register's original contents.
local M = {}

local function do_surround(motion_type, wrapper)
  local sel_save = vim.o.selection
  vim.o.selection = "inclusive"
  local reg_save = vim.fn.getreg('"')
  local reg_type_save = vim.fn.getregtype('"')

  if motion_type == "v" then
    -- Visual-mode call: re-select and yank the '<,'> marks.
    vim.cmd("normal! `<v`>y")
  else
    -- Operator-pending call: yank the '[,'] marks left by the motion.
    vim.cmd("normal! `[v`]y")
  end

  local yanked = vim.fn.getreg('"')
  vim.fn.setreg('"', wrapper .. yanked .. wrapper)
  vim.cmd("normal! gvp")

  vim.o.selection = sel_save
  vim.fn.setreg('"', reg_save, reg_type_save)
end

-- <Leader>fb / <Leader>fbiw: wrap in '**' (markdown bold).
function M.surround_bold(motion_type)
  do_surround(motion_type, "**")
end

-- <Leader>fi / <Leader>fiiw: wrap in '*' (markdown italic).
function M.surround_italic(motion_type)
  do_surround(motion_type, "*")
end

-- <Leader>fs / <Leader>fsiw: wrap in '~~' (markdown strikethrough).
function M.surround_strikethrough(motion_type)
  do_surround(motion_type, "~~")
end

-- 'operatorfunc' only accepts a plain global-function-name string (not an
-- arbitrary v:lua expression like a require() chain), so expose thin
-- globals for the buffer-local opfunc mappings in ftplugin/vimwiki.lua to
-- point at.
_G.__vimwiki_surround_bold = M.surround_bold
_G.__vimwiki_surround_italic = M.surround_italic
_G.__vimwiki_surround_strikethrough = M.surround_strikethrough

return M
