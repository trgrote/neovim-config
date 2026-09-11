-- Javascript-specific config. Full Lua port of ftplugin/javascript.vim's
-- IntelliJ-style //<editor-fold desc="...">...//</editor-fold> region
-- folding.
vim.opt_local.spell = false

vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.__vimwiki_js_fold(v:lnum)"
vim.opt_local.foldtext = "v:lua.__vimwiki_js_foldtext()"

local function idea_fold_desc(lnum)
  return vim.fn.getline(lnum):match('desc="([^"]+)"')
end

-- 'foldexpr'/'foldtext' only accept a plain global-function-name string
-- (same constraint as 'operatorfunc' - see lua/vimwiki/surround.lua).
_G.__vimwiki_js_fold = function(lnum)
  local line = vim.fn.getline(lnum):lower()
  if line:match("^.*//<editor%-fold") then
    return ">1"
  elseif line:match("^.*//</editor%-fold") then
    return "<1"
  end
  return "-1"
end

_G.__vimwiki_js_foldtext = function()
  local desc = idea_fold_desc(vim.v.foldstart) or ""
  local fold_start = "+" .. string.rep("-", vim.v.foldlevel * 2)
  return fold_start .. desc
end

-- Wrap the visual selection in editor-fold markers with a prompted
-- description, e.g. place -> //<editor-fold desc="...">place//</editor-fold>
local function make_intellij_folding(desc)
  local start_line = vim.fn.line("'<")
  vim.fn.append(start_line - 1, '//<editor-fold desc="' .. desc .. '">')
  -- Re-fetch '> after the insertion above: Vim auto-shifts the mark down
  -- by one line to keep pointing at the same content.
  local end_line = vim.fn.line("'>")
  vim.fn.append(end_line, "//</editor-fold>")
  vim.cmd("normal! vat=")
end

vim.keymap.set("v", "<leader>e", function()
  make_intellij_folding(vim.fn.input("Description: "))
end, { buffer = true })
