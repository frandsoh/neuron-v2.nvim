RELOAD("neuron_v2.helpers")
local popup = require "popup.init"
local utils = require "neuron_v2.utils"
local log = require "neuron_v2.log"
local helpers = require "neuron_v2.helpers"
local M = {}

---Get links from extmark
---@param bufnr number
---@param extmark_tbl table
local function get_link_info(bufnr, extmark_tbl)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  for _, line_nr in pairs(vim.tbl_keys(extmark_tbl)) do
    local links = {}
    -- log.debug(line_nr)

    local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)
    log.debug(lines)
    for _, line in pairs(lines) do
      for link in helpers.link_scanner(line, _, {row = line_nr}) do
        table.insert(links, link)
      end
    end
    log.debug(links)
  end
  -- log.debug(row, type(row))
  -- local find_in_line = vim.api.nvim_buf_get_lines(bufnr, row + 1, false)
  -- log.debug(tostring(find_in_line[1]))
  -- local links = helpers.link_scanner(tostring(find_in_line[1]), _)
  -- for link in links do
  --   log.debug({link})
  -- end
  -- local ext_id = extmark[1]
  -- local ext_row = extmark[2]
  -- local ext_col = extmark[3]
  -- local ext_end_row = extmark[4]["end_row"]
  -- local ext_end_col = extmark[4]["end_col"]
  -- log.debug({bufnr, ext_id, ext_row, ext_col, ext_end_row, ext_end_col})
  -- local line = vim.api.nvim_buf_get_lines(bufnr, ext_row, ext_row + 1, false)
  -- log.debug(line)
end

function M.show_links(bufnr, ns_id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  ns_id = ns_id or vim.api.nvim_create_namespace("neuron_v2")
  local all_extmarks = utils.buf_all_extmarks(bufnr, ns_id)
  -- log.debug(all_extmarks)
  local extmark_tbl = {}
  for _, e in pairs(all_extmarks) do
    extmark_tbl[e[2]] = extmark_tbl[e[2]] or {}
    table.insert(extmark_tbl[e[2]], e)
  end
  -- log.debug(extmark_tbl)
  get_link_info(bufnr, extmark_tbl)
end

-- vim.cmd [[nnoremap asdf <cmd>lua require("neuron_v2.popup").show_links()<CR>]]
return M
