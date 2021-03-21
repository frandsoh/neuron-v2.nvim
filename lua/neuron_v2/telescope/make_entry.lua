local entry_display = require "telescope.pickers.entry_display"
local neuron_dir = require("neuron_v2.config").neuron_dir
local make_entry = {}

function make_entry.gen_from_neuron_query(opts)
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
    -- local sub_time = string.sub(entry.value.Date, 12)

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

return make_entry