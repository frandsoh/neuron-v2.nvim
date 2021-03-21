-- if !exists("g:neuron_no_mappings") || ! g:neuron_no_mappings
--  nm gzn <Plug>EditZettelNew
--  nm gzN <Plug>EditZettelNewFromCword
--  vm gzN <esc><Plug>EditZettelNewFromVisual
--  nm gzr <Plug>NeuronRefreshCache
--  nm gzu <Plug>EditZettelLast
--  nm gzU :<C-U>call neuron#move_history(-1)<cr>
--  nm gzP :<C-U>call neuron#move_history(1)<cr>
--  nm gzz <Plug>EditZettelSelect
--  nm gzZ <Plug>EditZettelBacklink
--  nm gzo <Plug>EditZettelUnderCursor
--  nm gzs <Plug>EditZettelSearchContent
--  nm gzS <Plug>EditZettelSearchContentUnderCursor
--  nm gzl <Plug>InsertZettelLast
--  nm gzi <Plug>InsertZettelSelect
--  nm gzL :<C-U>call neuron#insert_zettel_last(1)<cr>
--  nm gzI :<C-U>call neuron#insert_zettel_select(1)<cr>
--  nm gzv <Plug>ToggleBacklinks
--  nm gzt <Plug>TagsAddNew
--  nm gzT <Plug>TagsAddSelect
--  nm gzts <Plug>TagsZettelSearch
--  ino <expr> <c-x><c-u> neuron#insert_zettel_complete(0)
--  ino <expr> <c-x><c-y> neuron#insert_zettel_complete(1)
-- end

---@class Path
local Path = require("plenary.path")

local log = require("neuron_v2.log")

local Config = {}

Config.__index = Config

function Config:validate()
  vim.validate {
    -- neuron_dir = {self.neuron_dir, "string"},
    use_default_mappings = {self.use_default_mappings, "boolean"},
    mappings = {self.mappings, "table"},
    virtual_titles = {self.virtual_titles, "boolean"},
    gen_cache_on_write = {self.gen_cache_on_write, "boolean"},
    virtual_text_highlight = {self.virtual_text_highlight, "string"},
    debug = {self.debug, "boolean"}
  }
  local exists = self.neuron_dir:exists()
  -- log.debug(exists)
  if not exists then
    error(
      string.format(
        "The directory %s does not exist. Please suply a valid dir for the neuron_v2 setup",
        self.neuron_dir.filename
      )
    )
    log.debug(
      string.format(
        "The directory %s does not exist. Please suply a valid dir for the neuron_v2 setup",
        self.neuron_dir.filename
      )
    )
  end
  local dhall = self.neuron_dir:joinpath("neuron.dhall")
  -- log.debug(dhall)
  if not dhall:exists() then
    error(
      ("The neuron_dir: %s does not include a neuron.dhall file - create one and try again"):format(
        self.neuron_dir.filename
      )
    )
  end
end

local mappings = {
  leader = "gz",
  create_link = "<CR>",
  edit_zettel_new = "n",
  edit_zettel_new_cursor_word = "N",
  edit_zettel_last = "u",
  edit_zettel_select = "z",
  goto_index = "i",
  start_server = "s",
  open_page = "o"
}
function Config:extend(user_config)
  for k, v in pairs(user_config.mappings) do
    self.mappings[k] = v
  end
  user_config.mappings = nil

  for k, v in pairs(user_config) do
    self[k] = v
  end
  -- log.debug(type(self.neuron_dir), self.neuron_dir)
  -- if type(self.neuron_dir) == "string" then
  --   self.neuron_dir = self:new_path(self.neuron_dir)
  -- -- elseif type(self.neuron_dir) == "table" then
  -- --   self.neuron_dir = self.neuron_dir
  -- end
  -- self.neuron_dir
  return true
end

function Config:after_extend(dir)
  ---@type Path
  dir = vim.fn.expand(dir)
  self.neuron_dir = Path:new(dir)

  -- log.debug(type(self.neuron_dir), self.neuron_dir)
  self:validate()
end

function Config:setup(user_config)
  self:extend(user_config)
  self:after_extend(self.neuron_dir)
end

-- function Config:new_path(string)
--   return Path:new(string)
-- end

local obj = {
  ---@type Path
  neuron_dir = vim.fn.expand("~/neuron"),
  use_default_mappings = true, -- to set default mappings
  mappings = mappings,
  virtual_titles = true, -- set virtual titles
  gen_cache_on_write = true, -- regenerate cache on write
  virtual_text_highlight = "Comment", -- the highlight color for the virtual titles
  debug = false -- to debug the plugin, set this to true
}

setmetatable(obj, Config)

return obj
