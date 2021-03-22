local Job = require("plenary.job")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")

-- neuron_v2
local neuron_dir = require("neuron_v2.config").neuron_dir
local log = require("neuron_v2.log")
local make_entry = require("neuron_v2.telescope.make_entry")
local n_actions = require("neuron_v2.telescope.actions")

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
    -- log.debug(opts.tag_width)
    -- log.debug(opts.title_width)
    local picker_opts = {
      prompt_title = "Find Zettels",
      -- results_title = "Title - Date - ID",
      finder = finders.new_table {
        results = json,
        entry_maker = make_entry.gen_from_neuron_query(opts)
      },
      previewer = previewers.vim_buffer_cat.new(opts),
      sorter = sorters.get_fzy_sorter(opts),
      layout_strategy = "vertical",
      sorting_strategy = "descending"
    }

    if opts.insert then
      picker_opts.attach_mappings = function()
        actions.select_default:replace(n_actions.insert_entry("ID"))
        return true
      end
    end

    pickers.new(opts, picker_opts):find()
  end
end

function M.find_tags(opts)
  opts = opts or {}
  local result
  local go_on = false
  local query_job =
    Job:new {
    command = "neuron",
    args = {"-d", neuron_dir.filename, "query", "--cached", "--tags"},
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
    -- TODO(frandsoh): adjust window size
    local picker_opts = {
      prompt_title = "Tags",
      results_title = "All Tags",
      finder = finders.new_table {
        results = json,
        entry_maker = make_entry.gen_from_all_tags(opts)
      },
      sorter = sorters.get_fzy_sorter(opts),
      layout_strategy = "vertical",
      sorting_strategy = "descending"
    }

    picker_opts.attach_mappings = function()
      actions.select_default:replace(n_actions.create_tag_picker(opts))
      return true
    end

    pickers.new(opts, picker_opts):find()
  end
end

function M.show_graph(opts)
  opts = opts or {}
  local result
  local go_on = false
  local query_job =
    Job:new {
    command = "neuron",
    args = {"-d", neuron_dir.filename, "query", "--cached", "--graph"},
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
    local adjacencyMap = json.result.adjacencyMap
    local vertices = json.result.vertices
    -- log.debug(adjacencyMap)
    log.debug(vertices)
    for k, v in pairs(adjacencyMap) do
      if vim.tbl_isempty(v) then
        vertices[k] = nil
      else
        vertices[k]["adjacent"] = v
      end
    end
    log.debug(vertices)
    local results = {}
    for _, v in pairs(vertices) do
      table.insert(results, v)
    end

    log.debug(results)
  end
end

function M.find_unconnected_zettels(opts)
  opts = opts or {}
  local result
  local go_on = false
  local query_job =
    Job:new {
    command = "neuron",
    args = {"-d", neuron_dir.filename, "query", "--cached", "--graph"},
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
    local adjacencyMap = json.result.adjacencyMap
    local vertices = json.result.vertices
    -- log.debug(adjacencyMap)
    -- log.debug(vertices)
    for k, v in pairs(adjacencyMap) do
      if not vim.tbl_isempty(v) then
        vertices[k] = nil
      end
    end
    -- log.debug(vertices)
    local results = {}
    for _, v in pairs(vertices) do
      table.insert(results, v)
    end
    log.debug(results)

    opts.title_width = 0
    opts.tag_width = 0
    for _, v in pairs(results) do
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
    local picker_opts = {
      prompt_title = "Find unconnected Zettels",
      -- results_title = "Title - Date - ID",
      finder = finders.new_table {
        results = results,
        entry_maker = make_entry.gen_from_neuron_query(opts)
      },
      previewer = previewers.vim_buffer_cat.new(opts),
      sorter = sorters.get_fzy_sorter(opts),
      layout_strategy = "vertical",
      sorting_strategy = "descending"
    }

    if opts.insert then
      picker_opts.attach_mappings = function()
        actions.select_default:replace(n_actions.insert_entry("ID"))
        return true
      end
    end

    pickers.new(opts, picker_opts):find()
  end
end

return M
