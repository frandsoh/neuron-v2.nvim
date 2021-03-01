local _, Path = pcall(require, "plenary.path")
if not Path then
  return print("neuron_v2 requires nvim-lua/plenary.nvim to work!")
end
local Job = require("plenary.job")
local config = require("neuron_v2.config")
local log = require("neuron_v2.log")

local helpers = {}

local function msub(line, s, f)
  return line:sub(s, f) .. vim.fn.strcharpart(line:sub(f + 1), 0, 1)
end

-- https://github.com/srid/neuron/blob/448a3d7d6ee19d0a9c52b29fee7b6c6b8ae6b2d9/neuron/src/lib/Neuron/Zettelkasten/ID.hs#L82
-- local allowed_special_chars = {"_", "-", ".", " ", ",", ";", "(", ")", ":", '"', "'", "@"}

function helpers.link_scanner(line)
  local pos = 1
  return function()
    while true do
      local start, finish = line:find('[#]-%[%[[^%[%]]-[%w%d%_%-%.%,%;%(%)%:%"%\'%@]+%]%][#]-', pos)
      if not start then
        break
      end
      pos = finish + 1

      local str = line:sub(start, finish)

      return {
        str = str,
        name = str:match("%[%[(.-)%]%]"),
        link = str:match("%[%[(.-)%]%]"),
        start = start,
        finish = finish
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
    if x >= v.start and x <= v.finish then
      return v
    end
  end
end

function helpers.open()
  local link = helpers.get_link_under_cursor()
  if not link then
    return
  end

  -- local current_file = vim.fn.expand("%:t")
  local file = link["name"] .. ".md"
  local path = config.neuron_dir:joinpath(file):expand()
  local is_new = not Path:new(path):exists()

  if is_new then
    vim.cmd("write")
    Job:new {
      command = "neuron",
      args = {"-d", config.neuron_dir:expand(), "new", link["name"]},
      cwd = config.neuron_dir:expand(),
      on_exit = vim.schedule_wrap(
        function()
          local created_note = Path:new(path):exists()
          if created_note then
            vim.cmd("e " .. path)
            local last_line = vim.api.nvim_buf_line_count(0)

            vim.api.nvim_buf_set_lines(
              0,
              last_line,
              last_line,
              false,
              {
                "",
                ("# %s"):format(link["name"])
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
  vim.cmd("e " .. path)
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

  local line = vim.api.nvim_get_current_line()
  -- local file_name = word.str:gsub(" ", "_"):lower() .. "_" .. vim.fn.strftime("%d%m%y%H%M%S") .. ".md"

  local str = ("%s[[%s]]%s"):format(line:sub(0, word.start), word.str, line:sub(word.finish + 1))

  vim.api.nvim_set_current_line(str)
end

function helpers.open_or_create()
  if helpers.get_link_under_cursor() then
    helpers.open()
  else
    helpers.create_link()
  end
end

return helpers
