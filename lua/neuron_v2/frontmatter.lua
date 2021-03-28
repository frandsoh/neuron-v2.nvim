local yaml
if not pcall(require, "lyaml") then
  print([[neuron_v2.frontmatter requires "lyaml". Please install it using luarocks]])
  return
else
  yaml = require "lyaml"
end
local log = require("neuron_v2.log")
-- TODO(frandsoh): in packer --> use_rocks "lyaml" or {..., rocks = "lyaml"}

---@class Markdown_data : table
---@field metadata table<string, nil>|nil Metadata from the YAML header as a Lua table
---@field markdown string The markdown without YAML (if the YAML is formatted correctly)

---@class Frontmatter : table
local Frontmatter = {}

local fm_token_start = "---"
local fm_token_end = "---"

---Set the start/end delimiter for the YAML markdown.
--- Defaults to "---"
--- @param start_delimiter string
--- @param end_delimiter string
function Frontmatter.set_metadata_delimiters(start_delimiter, end_delimiter)
  fm_token_start = start_delimiter
  fm_token_end = end_delimiter
end

---Get yaml frontmatter from file
---@param path string
---@param opts? table
---@return fun(x:string,y:table):Markdown_data
function Frontmatter.from_file(path, opts)
  opts = opts or {}
  local f = assert(io.open(path, "rb"))
  ---@ type string
  local src = f:read("*all")
  f:close()
  return Frontmatter.from_string(src, opts)
end

--- Get yaml frontmatter from string
--- The string must include the YAML delimiters.
--- Set the delimiters with Frontmatter.set_metadata_delimiters()
---@param full_text string
---@param opts? table
---@return Markdown_data table
function Frontmatter.from_string(full_text, opts)
  opts = opts or {}
  ---@type Markdown_data
  local result = {}

  local ts_pos_start, ts_pos_end = string.find(full_text, fm_token_start, 0, true)
  local te_pos_start, te_pos_end = string.find(full_text, fm_token_end, ts_pos_end, true)

  if ts_pos_start ~= nil and ts_pos_end ~= nil and te_pos_start ~= nil and te_pos_end ~= nil then
    local src_metadata = string.sub(full_text, ts_pos_end + 2, te_pos_start - 2)

    local status, data = pcall(yaml.load, src_metadata)

    if not status then
      log.debug(data)
      result.metadata = nil
    else
      result.metadata = data
    end

    result.markdown = string.sub(full_text, te_pos_end + 2, #full_text)
  else
    result.metadata = nil
    result.markdown = full_text
  end

  return result
end

return Frontmatter
