-- local Path = require("plenary.path")
local Job = require("plenary.job")
local config = require("neuron_v2.config")
local utils = require("neuron_v2.utils")
local helpers = require("neuron_v2.helpers")

local neuron_v2 = {}

neuron_v2.namespace = vim.api.nvim_create_namespace("neuron_v2")

-- Ignore if already in the buffer or open the win if it's edited
function neuron_v2.goto_index()
  vim.cmd("e " .. config.neuron_dir:joinpath("index.md").filename)
  vim.api.nvim_set_current_dir(config.neuron_dir.filename)
end

local function setup_autocmds()
  local pathpattern = string.format("%s/**.md", config.neuron_dir.filename)
  vim.cmd [[augroup NeuronV2]]
  vim.cmd [[au!]]
  vim.cmd(string.format("au BufRead %s lua require('neuron_v2').buffer_attach()", pathpattern))
  -- vim.cmd(string.format("au BufRead %s lua require('neuron_v2').buffer_set_extmarks()", pathpattern))
  if config.gen_cache_on_write == true then
    vim.cmd(string.format("au BufWritePost %s lua require('neuron_v2').gen()", pathpattern))
  end
  if config.use_default_mappings == true then
    require("neuron_v2.mappings").setup()
  end
  vim.cmd [[augroup END]]
end

---Setup neuron_v2
---@param user_config table
function neuron_v2.setup(user_config)
  if vim.fn.executable("neuron") == 0 then
    vim.cmd [[echo "Couldn't find neuron in your PATH - Aborting neuron_v2 setup"]]
    return
  end

  user_config = user_config or {}
  config:setup(user_config)

  setup_autocmds()
  require("neuron_v2.log").debug("neuron_v2 initiaded")
end

function neuron_v2.serve_and_watch(opts)
  opts = opts or {}
  opts.address = opts.address or "127.0.0.1:8080"

  NeuronServe =
    Job:new {
    command = "neuron",
    cwd = config.neuron_dir:expand(),
    args = {"gen", "-w", "-s", opts.address, "--pretty-urls"},
    interactive = false,
    on_start = vim.schedule_wrap(
      function()
        require("neuron_v2.log").debug("Neuron server started")

        if opts.open then
          utils.os_open(NeuronServe.address)
          require("neuron_v2.log").debug("Opening neuron server")
        end
      end
    )
  }
  NeuronServe.address = utils.get_localhost_address(opts.address)
  require("neuron_v2.log").debug(NeuronServe.address)
  NeuronServe:start()

  vim.cmd [[augroup NeuronServeStop]]
  vim.cmd [[au!]]
  vim.cmd [[au VimLeave * lua require('neuron_v2').stop_server()]]
  vim.cmd [[augroup END]]
end

function neuron_v2.open_page()
  if not NeuronServe then
    neuron_v2.serve_and_watch({open = false})
  end
  local id = utils.get_current_zettel_id()
  if id == "index" then
    utils.os_open(NeuronServe.address)
    return
  end
  local slug_job = utils.get_slug(id)
  local slug
  slug_job:add_on_exit_callback(
    vim.schedule_wrap(
      function(self, _, _)
        local result = vim.fn.json_decode(self:result())
        require("neuron_v2.log").debug(vim.inspect(result["Slug"]))
        slug = result["Slug"]
        utils.os_open(NeuronServe.address .. "/" .. slug)
      end
    )
  )
  slug_job:start()
end

function neuron_v2.stop_server()
  if NeuronServe ~= nil then
    vim.loop.kill(NeuronServe.pid, 15) -- sigterm
    NeuronServe = nil
  end
end
function neuron_v2.gen()
  if NeuronServe then
    return
  end
  Job:new {
    command = "neuron",
    args = {"gen"},
    cwd = config.neuron_dir:expand(),
    interactive = false,
    on_exit = vim.schedule_wrap(
      function()
        require("neuron_v2.log").debug("OK - Generated neuron cache")
      end
    )
  }:start()
end

function neuron_v2.buffer_set_extmarks(buf_nr)
  buf_nr = buf_nr or 0
  for line_nr, line in ipairs(vim.api.nvim_buf_get_lines(buf_nr, 0, -1, false)) do
    neuron_v2.line_set_extmarks(buf_nr, line_nr, line)
  end
end

function neuron_v2.line_set_extmarks(buf_nr, line_nr, line)
  for link in helpers.link_scanner(line) do
    local start_col, end_col, str = link.col, link.end_col, link.str
    local ns_id = neuron_v2.namespace

    vim.api.nvim_buf_set_extmark(
      buf_nr,
      ns_id,
      line_nr - 1,
      start_col - 1,
      {
        end_col = end_col,
        virt_text = {{str, "Comment"}},
        virt_text_pos = "eol"
      }
    )
  end
end

local function buffer_update_on_lines(bufnr, first_line, last_line_updated)
  local log = require("neuron_v2.log").debug
  local ns_id = neuron_v2.namespace

  local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, last_line_updated, false)

  if first_line < last_line_updated then
    for i = first_line, last_line_updated - 1 do
      local links = {}
      for link in helpers.link_scanner(lines[i - first_line + 1]) do
        table.insert(links, link)
      end
      for _, link in pairs(links) do
        local start_col, end_col, zettelid, zettel_exists = link.col, link.end_col, link.zettelid, link.exists
        local extmark_id
        local extmarks_in_line = utils.line_all_extmarks(bufnr, ns_id, i)
        -- log({extmarks_in_line})
        for _, e in pairs(extmarks_in_line) do
          if start_col - 1 == e[3] or end_col == e[4]["end_col"] then
            extmark_id = e[1]
            break
          else
            extmark_id = nil
          end
        end
        -- local zettel_path = config.neuron_dir:joinpath(zettelid .. ".md")
        -- local zettel_exists = zettel_path:exists()
        -- local zettel_exists = link.zettel_data
        local hl_group
        if zettel_exists then
          hl_group = "Green"
        else
          hl_group = "Red"
        end
        vim.api.nvim_buf_set_extmark(
          bufnr,
          ns_id,
          i,
          start_col - 1,
          {
            id = extmark_id,
            end_col = end_col,
            hl_group = hl_group
            -- virt_text = {{link.str, hl_group}},
            -- virt_text_pos = "overlay"
          }
        )
      end
      local extmarks_in_line = utils.line_all_extmarks(bufnr, ns_id, i)
      local count_extmarks = #extmarks_in_line or 0
      local count_links = #links or 0
      while count_extmarks > count_links do
        if count_links == 0 then
          for _, e in pairs(extmarks_in_line) do
            vim.api.nvim_buf_del_extmark(bufnr, ns_id, e[1])
            count_extmarks = count_extmarks - 1
            -- log("deleted", e[1])
          end
        end
        for _, e in pairs(extmarks_in_line) do
          local found_match
          for _, link in pairs(links) do
            if link.col - 1 == e[3] and link.end_col == e[4]["end_col"] then
              found_match = true
              break
            else
              found_match = false
            end
          end
          if not found_match then
            vim.api.nvim_buf_del_extmark(bufnr, ns_id, e[1])
            count_extmarks = count_extmarks - 1
          end
        end
      end
    end
  end
  local all_extmarks = utils.buf_all_extmarks(bufnr, ns_id)
  for _, e in pairs(all_extmarks) do
    -- Delete extmarks if they are at position 0,0
    if e[3] == e[4]["end_col"] then
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, e[1])
    end

    --- Delete extmarks if they are too short, e.g "[[]]"
    if (e[4]["end_col"] - e[3]) <= 4 then
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, e[1])
    end
  end
end

function neuron_v2.buffer_attach()
  local bufnr = vim.fn.bufnr("%")
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- local ns_id = neuron_v2.namespace
  buffer_update_on_lines(bufnr, 0, line_count)
  vim.api.nvim_buf_attach(
    bufnr,
    false,
    {
      -- on_lines = vim.schedule_wrap(
      --   function(...)
      --     local event = {...}
      --     buffer_update_on_lines(event[2], event[4], event[6])
      --   end
      -- )
      on_lines = vim.schedule_wrap(
        function(...)
          local event = {...}
          buffer_update_on_lines(event[2], event[4], event[6])
        end
      )
      -- on_detach = function(...)
      --   local event = {...}
      --   vim.api.nvim_buf_clear_namespace(event[2], ns_id, 0, -1)
      --   require("neuron_v2.log").debug("namespace cleared")
      --   -- buffer_update_on_lines(event[2], 0, line_count)
      -- end,
      -- on_reload = function(...)
      --   local event = {...}
      --   vim.api.nvim_buf_clear_namespace(event[2], ns_id, {0}, {-1})
      --   require("neuron_v2.log").debug("namespace cleared")
      --   buffer_update_on_lines(event[2], 0, line_count)
      -- end
    }
  )
end

return neuron_v2
