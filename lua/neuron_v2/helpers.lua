local Job = require("plenary.job")
local config = require("neuron_v2.config")
local log = require("neuron_v2.log")
local utils = require("neuron_v2.utils")

local helpers = {}

local function msub(line, s, f)
  return line:sub(s, f) .. vim.fn.strcharpart(line:sub(f + 1), 0, 1)
end

function helpers.zettel_exists(zettelid)
  local zettel_path = config.neuron_dir:joinpath(zettelid .. ".md")
  return zettel_path:exists()
end

function helpers.zettel_path(zettelid)
  return config.neuron_dir:joinpath(zettelid .. ".md")
end

---Scan line for links
-- https://github.com/srid/neuron/blob/448a3d7d6ee19d0a9c52b29fee7b6c6b8ae6b2d9/neuron/src/lib/Neuron/Zettelkasten/ID.hs#L82
-- local allowed_special_chars = {"_", "-", ".", " ", ",", ";", "(", ")", ":", '"', "'", "@"}
---@param line string|table
---@param pos any
---@param opts any
---@return function
function helpers.link_scanner(line, pos, opts)
  opts = opts or {}
  assert(type(opts) == "table", "link_scanner() param opts is not a table")
  pos = pos or 1

  return function()
    while true do
      local link = {string.find(line, '(([#]?)(%[%[[^%[%]]-))([%w%d% %_%-%.%,%;%(%)%:%"%\'%@]+)((%]%])([#]?))', pos)}
      local start, finish = link[1], link[2]
      if not start then
        break
      end

      local zettelid = link[6]

      local zettel_path = require("neuron_v2.helpers").zettel_path(zettelid)
      local zettel_exists = zettel_path:exists()

      -- if the link has a # at the start and end, ignore them
      if link[3]:len() == 3 and link[7]:len() == 3 then
        start = start + 1
        finish = finish - 1
      end

      local str = line:sub(start, finish)

      pos = finish + 1
      return {
        str = str,
        row = opts.row,
        exists = zettel_exists,
        zettelid = zettelid,
        bufnr = opts.bufnr,
        col = start,
        end_col = finish
      }
    end
  end
end

-- based on
-- https://github.com/notomo/curstr.nvim/blob/fa35837da5412d1a216bd832f827464d7ac7f0aa/lua/curstr/core/cursor.lua#L20
function helpers.cword()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local pattern = ("\\v\\k*%%%sc\\k+"):format(pos[2] + 1)
  local str, start_byte = unpack(vim.fn.matchstrpos(line, pattern))
  if start_byte == -1 then
    return
  end
  local after_part = vim.fn.strpart(line, start_byte)
  local start = #line - #after_part
  local finish = start + #str
  return {
    str = str,
    start = start,
    finish = finish
  }
end

function helpers.get_visual()
  local s = vim.fn.getpos("'<")
  local f = vim.fn.getpos("'>")
  assert(s[2] == f[2], "Can't make multiline links")
  local str = msub(vim.api.nvim_get_current_line(), s[3], f[3] - 1)
  local start = s[3] - 1
  local finish = start + str:len()

  return {
    str = str,
    start = start,
    finish = finish
  }
end

function helpers.get_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local x = vim.api.nvim_win_get_cursor(0)[2] + 1

  for v in helpers.link_scanner(line) do
    if x >= v.col and x <= v.end_col then
      return v
    end
  end
end

function helpers.open()
  local link = helpers.get_link_under_cursor()
  if not link then
    return
  end
  -- TODO(frandsoh): Update to use link.exists and helpers.zettel_path
  local file_name = link.zettelid .. ".md"
  local file_path = config.neuron_dir:joinpath(file_name)
  local is_new = not file_path:exists()

  if is_new then
    -- vim.cmd [[write]]
    Job:new {
      command = "neuron",
      args = {"-d", config.neuron_dir.filename, "new", link.zettelid},
      cwd = config.neuron_dir.filename,
      on_exit = vim.schedule_wrap(
        function()
          local created_note = file_path:exists()
          if created_note then
            vim.cmd("e " .. file_path:expand())
            local last_line = vim.api.nvim_buf_line_count(0)

            -- To insert lines at a given index, set `start` and `end` to the
            -- same index. To delete a range of lines, set `replacement` to
            -- an empty array.
            vim.api.nvim_buf_set_lines(
              0,
              last_line,
              last_line,
              false,
              {
                "",
                ("# %s"):format(link.zettelid)
              }
            )
            vim.api.nvim_set_current_dir(config.neuron_dir:expand())
          else
            log.debug("Could not create new note")
          end
        end
      )
    }:start()
    return
  end
  vim.cmd("e " .. file_path:expand())
  vim.api.nvim_set_current_dir(config.neuron_dir:expand())
end

function helpers.create_link(visual)
  local word

  if visual then
    word = helpers.get_visual()
  else
    word = helpers.cword()
  end

  if not word then
    return
  end

  local pos = vim.fn.getpos(".") -- returns [bufnum, lnum, col, off]
  local buf = pos[1] -- bufnum
  local start_row = pos[2] - 1 -- lnum
  local start_col = word.start
  local end_row = start_row
  local end_col = word.finish
  local replacement = ("[[%s]]"):format(word.str)

  -- To insert text at a given index, set `start` and `end` ranges
  -- to the same index. To delete a range, set `replacement` to an
  -- array containing an empty string, or simply an empty array.
  vim.api.nvim_buf_set_text(buf, start_row, start_col, end_row, end_col, {replacement})
end

function helpers.open_or_create()
  if helpers.get_link_under_cursor() then
    helpers.open()
  else
    helpers.create_link()
  end
end

return helpers
