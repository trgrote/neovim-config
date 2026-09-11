-- ADF (Atlassian Document Format) -> plain markdown lines. Not a full ADF
-- renderer - handles the common cases (paragraphs, headings, hard breaks,
-- links, bullet/ordered lists) and best-effort flattens anything else
-- (tables, panels, media, ...) rather than erroring on them. Full Lua port
-- of s:AdfInlineToText/s:AdfBlockToLines/s:AdfDocToLines(Safe).
local M = {}

local function is_table(x)
  return type(x) == "table"
end

-- Mirrors vim's split(text, "\n", 1): splits on "\n", keeping empty
-- leading/trailing/interior segments.
local function split_keepempty(text, sep)
  local result = {}
  local pos = 1
  while true do
    local s, e = text:find(sep, pos, true)
    if not s then
      table.insert(result, text:sub(pos))
      break
    end
    table.insert(result, text:sub(pos, s - 1))
    pos = e + 1
  end
  return result
end

function M.inline_to_text(node)
  if not is_table(node) then
    return ""
  end
  local node_type = node.type or ""

  if node_type == "text" then
    local text = node.text or ""
    for _, mark in ipairs(node.marks or {}) do
      if is_table(mark) and mark.type == "link" then
        local href = (is_table(mark.attrs) and mark.attrs.href) or ""
        if href ~= "" then
          text = string.format("[%s](%s)", text, href)
        end
      end
    end
    return text
  elseif node_type == "hardBreak" then
    return "\n"
  elseif is_table(node.content) and vim.islist(node.content) then
    local parts = {}
    for _, child in ipairs(node.content) do
      table.insert(parts, M.inline_to_text(child))
    end
    return table.concat(parts)
  else
    return ""
  end
end

function M.block_to_lines(node)
  if not is_table(node) then
    return {}
  end
  local node_type = node.type or ""

  if node_type == "paragraph" or node_type == "heading" then
    local parts = {}
    for _, child in ipairs(node.content or {}) do
      table.insert(parts, M.inline_to_text(child))
    end
    return split_keepempty(table.concat(parts), "\n")
  elseif node_type == "bulletList" or node_type == "orderedList" then
    local lines = {}
    local num = 1
    for _, item in ipairs(node.content or {}) do
      local item_lines = {}
      for _, child in ipairs((is_table(item) and item.content) or {}) do
        vim.list_extend(item_lines, M.block_to_lines(child))
      end
      if #item_lines > 0 then
        local prefix = node_type == "bulletList" and "- " or (num .. ". ")
        table.insert(lines, prefix .. item_lines[1])
        for i = 2, #item_lines do
          table.insert(lines, "  " .. item_lines[i])
        end
      end
      num = num + 1
    end
    return lines
  elseif is_table(node.content) and vim.islist(node.content) then
    local lines = {}
    for _, child in ipairs(node.content) do
      vim.list_extend(lines, M.block_to_lines(child))
    end
    return lines
  else
    return {}
  end
end

function M.doc_to_lines(doc)
  if not is_table(doc) or doc.type ~= "doc" then
    return {}
  end

  local blocks = {}
  for _, node in ipairs(doc.content or {}) do
    local block_lines = M.block_to_lines(node)
    if #block_lines > 0 then
      table.insert(blocks, block_lines)
    end
  end

  local result = {}
  for i, block in ipairs(blocks) do
    if i > 1 then
      table.insert(result, "")
    end
    vim.list_extend(result, block)
  end
  return result
end

function M.doc_to_lines_safe(doc)
  local ok, result = pcall(M.doc_to_lines, doc)
  if not ok then
    vim.notify("NewJiraTicket: could not fully parse the Jira description; leaving it out.", vim.log.levels.WARN)
    return {}
  end
  return result
end

return M
