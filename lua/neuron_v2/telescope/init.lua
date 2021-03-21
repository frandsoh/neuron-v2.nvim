local helpers = require("neuron_v2.helpers")
local Job = require("plenary.job")
local pickers = require("telescope.pickers")
local make_entry = require("neuron_v2.telescope.make_entry")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local neuron_dir = require("neuron_v2.config").neuron_dir
local actions = require("telescope.actions")
local entry_display = require("telescope.pickers.entry_display")
local path = require("telescope.path")
local utils = require("telescope.utils")
local log = require("neuron_v2.log")

local get_default = utils.get_default
local M = {}

function M.find_zettels(opts)
  opts = opts or {}
  local result
  local go_on = false
  local query_job =
    Job:new {
    command = "neuron",
    args = {"-d", neuron_dir.filename, "query", "--cached"},
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
    -- P(result)
    local json = vim.fn.json_decode(result)
    -- P(json)
    opts.title_width = 0
    opts.tag_width = 0
    for _, v in pairs(json) do
      if #v.Title > opts.title_width then
        opts.title_width = #v.Title
      end
      if #v.Meta.tags > 0 then
        local len = table.concat(v.Meta.tags, "   ")
        if #len > opts.tag_width then
          opts.tag_width = #len
        end
      end
    end
    if opts.tag_width >= 30 then
      opts.tag_width = 30
    end
    log.debug(opts.tag_width)
    -- log.debug(opts.title_width)
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

    -- if opts.insert then
    --   picker_opts.attach_mappings = function()
    --     actions.select_default:replace(neuron_actions.insert_maker("id"))
    --     return true
    --   end
    -- else
    --   picker_opts.attach_mappings = function()
    --     actions.select_default:replace(neuron_actions.edit_or_insert)
    --     return true
    --   end
    -- end

    pickers.new(opts, picker_opts):find()
  end
end

return M
