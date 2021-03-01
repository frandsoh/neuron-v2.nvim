-- RELOAD("neuron_v2.config")
local Job = require("plenary.job")
local config = require("neuron_v2.config")
local utils = require("neuron_v2.utils")

local neuron_v2 = {}

function neuron_v2.goto_index()
  vim.cmd("e " .. config.neuron_dir:joinpath("index.md"):expand())
  vim.api.nvim_set_current_dir(config.neuron_dir:expand())
end

local function setup_autocmds()
  local pathpattern = string.format("%s/**.md", config.neuron_dir:expand())
  vim.cmd [[augroup NeuronV2]]
  vim.cmd [[au!]]
  if config.gen_cache_on_write == true then
    vim.cmd(string.format("au BufWritePost %s lua require('neuron_v2').gen()", pathpattern))
  end
  if config.use_default_mappings == true then
    require("neuron_v2.mappings").setup()
  end
  vim.cmd [[augroup END]]
end

---Setup neuron_v2
--@param user_config table
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
    args = {"gen", "-w", "-s", opts.address},
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
  end
  local slug_job = utils.get_slug(id)
  local slug
  slug_job:add_on_exit_callback(
    vim.schedule_wrap(
      function(self, _, _)
        local result = vim.fn.json_decode(self:result())
        require("neuron_v2.log").debug(vim.inspect(result["Slug"]))
        slug = result["Slug"]
        utils.os_open(NeuronServe.address .. "/" .. slug .. ".html")
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

return neuron_v2
