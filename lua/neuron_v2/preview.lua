local helpers = require("neuron_v2.helpers")
local Job = require("plenary.job")
local pickers = require("telescope.pickers")
local make_entry = require("telescope.make_entry")
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

-- local function entry_maker(entry)
--   -- neuron now inputs this path instead with ./ in front
--   if vim.startswith(entry.Path, "./") then
--     entry.Path = entry.Path:sub(3)
--   end
--   local value = neuron_dir:joinpath(entry.Path).filename
--   P(value)
--   -- P(value)
--   -- local value = string.format("%s/%s", config.neuron_dir, entry.Path)

--   local display = entry.Title
--   return {display = display, value = value, ordinal = display, id = entry.ID}
-- end

local function make_entry_from_zettels(opts)
  opts = opts or {}
  -- opts.tail_path = true
  local title_width = opts.title_width or 20
  local tag_width = opts.tag_width or 40
  local displayer =
    entry_display.create {
    separator = " ▏",
    items = {
      {width = title_width},
      {width = tag_width},
      {remaining = true}
    }
  }

  local make_display = function(entry)
    local sub_date = string.sub(entry.value.Date, 1, 10)
    local sub_time = string.sub(entry.value.Date, 12)

    local zettel_title = {entry.value.Title, "TelescopeResultsIdentifier"}
    local zettel_id = {entry.value.ID, "TelescopeResultsLineNr"}
    local zettel_date = {sub_date, "TelescopeResultsLineNr"}
    local zettel_tags = function()
      if #entry.zettel_tags > 0 then
        return "#" .. entry.zettel_tags
      else
        return " "
      end
    end
    return displayer {
      zettel_title,
      zettel_tags(),
      zettel_date,
      zettel_id
    }
  end
  return function(entry)
    -- neuron now inputs this path instead with ./ in front
    local entry_path = entry.Path
    if vim.startswith(entry.Path, "./") then
      entry_path = entry.Path:sub(3)
    end
    local filename = neuron_dir:joinpath(entry_path).filename
    local zettel_tags
    if entry.Meta.tags then
      zettel_tags = table.concat(entry.Meta.tags, " #")
    end
    -- log.debug(entry)
    local entry_tbl = {
      valid = true,
      value = entry,
      ordinal = entry.Title .. " date:" .. entry.Date:sub(1, 10) .. " #" .. (zettel_tags or ""),
      display = make_display,
      filename = filename,
      zettel_tags = zettel_tags
    }
    -- log.debug(entry_tbl)
    return entry_tbl
  end
end

function M.show_preview(opts)
  opts = opts or {}
  local result
  local go_on = false
  local find_zettels =
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
  find_zettels:start()
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
        -- else
        --   opts.tag_width = 60
        end

      -- if opts.tag_width <= 40 then
      --   tag_width = opts.tag_width
      -- end
      end
    end
    if opts.tag_width >= 30 then
      opts.tag_width = 30
    end
    log.debug(opts.tag_width)
    -- log.debug(opts.title_width)
    local picker_opts = {
      prompt_title = "Find Zettels",
      results_title = "Title - Date - ID",
      finder = finders.new_table {
        results = json,
        entry_maker = make_entry_from_zettels(opts)
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
