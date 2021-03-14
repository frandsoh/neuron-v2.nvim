local Job = require("plenary.job")
local config = require("neuron_v2.config")
local log = require("neuron_v2.log")

local utils = {}

-- Open the path in browser
---@param path string
function utils.os_open(path)
  local os = vim.loop.os_uname().sysname

  local open_cmd
  if os == "Linux" then
    open_cmd = "xdg-open"
  elseif os == "Windows" then
    open_cmd = "start"
  elseif os == "Darwin" then
    open_cmd = "open"
  end

  Job:new {
    command = open_cmd,
    args = {path}
  }:start()
end

--- Get all extmarks in buffer
-- List of [extmark_id, row, col] tuples in "traversal order"
---@param bufnr number
---@param ns_id number
---@return table
function utils.buf_all_extmarks(bufnr, ns_id)
  return vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {details = true})
end

---Get all extmarks in line
---@param bufnr number
---@param ns_id number
---@param lnum number
function utils.line_all_extmarks(bufnr, ns_id, lnum)
  return vim.api.nvim_buf_get_extmarks(bufnr, ns_id, {lnum, 0}, {lnum, -1}, {details = true})
end

---@param s string
function utils.get_localhost_address(s)
  return s:gsub(".+(:%d+)", "http://localhost%1")
end

---@return string current_id
function utils.get_current_zettel_id()
  -- local log = require("neuron_v2.log")
  local current_id = vim.fn.expand("%:t:r")
  log.debug("Current id is: ", current_id)
  return current_id
end

---@param zettelid string
function utils.get_slug(zettelid)
  local slug_job =
    Job:new {
    command = "neuron",
    args = {"-d", config.neuron_dir:expand(), "query", "--cached", "--id", zettelid},
    cwd = config.neuron_dir:expand(),
    interactive = false
    -- on_exit = vim.schedule_wrap(
    --   function(self, _, _)
    --     local result = vim.fn.json_decode(self:result())
    --     require("neuron_v2.log").debug(vim.inspect(result["Slug"]))
    --     return result["Slug"]
    --   end
    -- )
  }
  return slug_job
end

---@param input table|string
function utils.query_id(input)
  local zettelid
  if type(input) == "table" then
    zettelid = input["zettelid"]
  elseif type(input) == "string" then
    zettelid = input
  end
  local query_job =
    Job:new {
    command = "neuron",
    args = {"-d", config.neuron_dir:expand(), "query", "--cached", "--id", zettelid},
    cwd = config.neuron_dir:expand(),
    interactive = false
  }

  return query_job
end

return utils
