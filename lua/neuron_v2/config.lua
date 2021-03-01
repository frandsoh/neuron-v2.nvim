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

local Path = require("plenary.path")
-- local _, Path = pcall(require, "plenary.path")
-- if not Path then
--   return print("neuron_v2 requires nvim-lua/plenary.nvim to work!")
-- end

-- local _, scandir = pcall(require, "plenary.scandir")
-- if not scandir then
--   return print("neuron_v2 requires nvim-lua/plenary.nvim to work!")
-- end

local Config = {}
Config.__index = Config

function Config:validate()
  vim.validate {
    neuron_dir = {self.neuron_dir:expand(), "string"},
    use_default_mappings = {self.use_default_mappings, "boolean"},
    mappings = {self.mappings, "table"}, -- the leader key to for all mappings
    virtual_titles = {self.virtual_titles, "boolean"},
    gen_cache_on_write = {self.gen_cache_on_write, "boolean"},
    virtual_text_highlight = {self.virtual_text_highlight, "string"},
    debug = {self.debug, "boolean"}
  }

  if not self.neuron_dir:exists() then
    error(string.format("The path '%s' supplied for the neuron_dir does not exist", self.neuron_dir:expand()))
  end

  if not self.neuron_dir:joinpath("neuron.dhall"):exists() then
    error(
      ("The neuron_dir: %s does not include a neuron.dhall file - create one and try again"):format(
        self.neuron_dir:expand()
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
  self.neuron_dir = Path:new(self.neuron_dir)
  self:validate()
end

-- function Config:after_extend()
--   self.neuron_dir = Path:new(self.neuron_dir)
--   -- P(self.neuron_dir)
-- end

function Config:setup(user_config)
  self:extend(user_config)
  -- self:after_extend()
end

return setmetatable(
  {
    neuron_dir = Path:new("~/neuron"):expand(),
    use_default_mappings = true, -- to set default mappings
    mappings = mappings,
    virtual_titles = true, -- set virtual titles
    gen_cache_on_write = true, -- regenerate cache on write
    virtual_text_highlight = "Comment", -- the highlight color for the virtual titles
    debug = false -- to debug the plugin, set this to true
  },
  Config
)
