RELOAD("neuron_v2.helpers")
-- local popup = require "popup.init"
local utils = require "neuron_v2.utils"
local log = require "neuron_v2.log"
local helpers = require "neuron_v2.helpers"
local Job = require("plenary.job")
local uv = vim.loop
local co = coroutine
local a = require("foh.async")
local neuron_dir = require("neuron_v2.config").neuron_dir.filename

local M = {}

---Get links from extmark
---@param bufnr number
---@param extmark_tbl table
local function get_link_info_from_extmarks(bufnr, extmark_tbl)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local links = {}
  for _, line_nr in pairs(vim.tbl_keys(extmark_tbl)) do
    -- log.debug(line_nr)

    local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)
    -- log.debug(lines)
    for _, line in pairs(lines) do
      for link in helpers.link_scanner(line, _, {row = line_nr}) do
        table.insert(links, link)
      end
    end
  end
  -- log.debug(links)
  return links
end

function M.show_links(bufnr, ns_id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  ns_id = ns_id or vim.api.nvim_create_namespace("neuron_v2")

  local all_extmarks = utils.buf_all_extmarks(bufnr, ns_id)

  if #all_extmarks == 0 then
    return P("No popup titles to show")
  end

  -- make a tbl where each key is a line number with at least 1 extmark
  local extmark_tbl = {}
  for _, e in pairs(all_extmarks) do
    -- e[2] is the row of the extmark
    extmark_tbl[e[2]] = extmark_tbl[e[2]] or {}
    table.insert(extmark_tbl[e[2]], e)
  end

  local links_in_buffer = get_link_info_from_extmarks(bufnr, extmark_tbl)

  local query_id = Job

  local jobs = {}
  local results = {}
  for _, l in pairs(links_in_buffer) do
    if l.exists then
      table.insert(
        jobs,
        query_id:new {
          command = "neuron",
          args = {
            "-d",
            neuron_dir,
            "query",
            "--cached",
            "--id",
            l.zettelid
          },
          on_exit = function(self, _, _)
            local result = self:result()
            if #result ~= 1 then
              table.insert(results, {link = l, result = result})
            else
              table.insert(results, {link = l, result = false})
            end
            return true
          end
        }
      )
    end
  end

  if #jobs > 0 then
    local status = Job.chain(unpack(jobs))
    if
      vim.wait(
        2000,
        function()
          return Job.chain_status(status)
        end
      )
     then
      for _, result in pairs(results) do
        if result.result then
          local zettel_data = vim.fn.json_decode(result.result)
          local cr = vim.tbl_deep_extend("error", result.link, zettel_data)
          -- log.debug({result.link, zettel_data})
          log.debug(cr)
          require("neuron_v2.popup").create(cr.Title, cr.col, cr.row)
        else
          log.debug(result.link .. " doesn't exist")
        end
      end
    end
  end
end

function M.create(title, col, row)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {title})
  local opts = {
    relative = "win",
    width = string.len(title),
    height = 1,
    bufpos = {row, col},
    anchor = "SW",
    focusable = false,
    style = "minimal"
  }
  local win_id = vim.api.nvim_open_win(bufnr, false, opts)
  vim.lsp.util.close_preview_autocmd({"CursorMoved", "CursorMovedI"}, win_id)
end

return M
