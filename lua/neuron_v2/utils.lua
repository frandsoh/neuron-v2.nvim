local Job = require("plenary.job")
local config = require("neuron_v2.config")

local utils = {}

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

--@param s string
function utils.get_localhost_address(s)
  return s:gsub(".+(:%d+)", "http://localhost%1")
end

function utils.get_current_zettel_id()
  local log = require("neuron_v2.log")
  local current_id = vim.fn.expand("%:t:r")
  log.debug("Current id is: ", current_id)
  return current_id
end

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
return utils
