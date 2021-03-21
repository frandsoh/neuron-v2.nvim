local neuron_dir = require("neuron_v2.config").neuron_dir
local log = require("neuron_v2.log")
local actions = require "telescope.actions"

-- TODO(frandsoh): take a look at other plugins

local M = {}

---@param key string
function M.insert_entry(key)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)

    local entry = actions.get_selected_entry()
    -- [bufnum, lnum, col, off]
    local pos = vim.fn.getpos(".")
    local bufnr = pos[1]
    local lnum = pos[2]
    local col = pos[3]
    -- P(entry)
    -- log.debug(bufnr, lnum, col)
    if key == "ID" then
      vim.api.nvim_buf_set_text(bufnr, lnum - 1, col - 1, lnum - 1, col - 1, {"[[" .. entry.value[key] .. "]]"})
    end
  end
end

return M
