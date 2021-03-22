local Job = require("plenary.job")
local finders = require("telescope.finders")
local neuron_dir = require("neuron_v2.config").neuron_dir
local make_entry = require "neuron_v2.telescope.make_entry"
local log = require("neuron_v2.log")
local actions = require "telescope.actions"
local sorters = require("telescope.sorters")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")

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
    else
      vim.api.nvim_buf_set_text(bufnr, lnum - 1, col - 1, lnum - 1, col - 1, {entry.value[key]})
    end
  end
end

function M.create_tag_picker(opts)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)

    local entry = actions.get_selected_entry()
    log.debug(entry)
    local result
    local go_on = false
    local query_job =
      Job:new {
      command = "neuron",
      args = {"-d", neuron_dir.filename, "query", "--cached", "--tag", entry.value},
      on_exit = vim.schedule_wrap(
        function(self)
          result = self:result()
          -- P(result)
          go_on = true
          return go_on
        end
      )
    }
    query_job:start()
    if
      vim.wait(
        2000,
        function()
          return go_on
        end
      )
     then
      local json = vim.fn.json_decode(result)
      log.debug(json)
      local picker_opts = {
        prompt_title = "Find Zettels",
        -- results_title = "Title - Date - ID",
        finder = finders.new_table {
          results = json,
          entry_maker = make_entry.gen_from_neuron_query(opts)
        },
        previewer = previewers.vim_buffer_cat.new(opts),
        -- sorter = sorters.get_substr_matcher(),
        -- sorter = conf.generic_sorter(opts),
        sorter = sorters.get_fzy_sorter(opts),
        layout_strategy = "vertical",
        sorting_strategy = "descending"
      }

      if opts.insert then
        picker_opts.attach_mappings = function()
          actions.select_default:replace(M.insert_entry("ID"))
          return true
        end
      end

      pickers.new(opts, picker_opts):find()
    end
  end
end

return M
