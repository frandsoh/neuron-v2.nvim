local config = require("neuron_v2.config")

local M = {}

local m = config.mappings
local leader_key = m.leader

function M.map_buf(key, rhs)
  local lhs = string.format("%s%s", leader_key, key)
  vim.api.nvim_buf_set_keymap(0, "n", lhs, rhs, {noremap = true, silent = true})
end

function M.map(key, rhs)
  local lhs = string.format("%s%s", leader_key, key)
  vim.api.nvim_set_keymap("n", lhs, rhs, {noremap = true, silent = true})
end

function M.set_keymaps()
  vim.api.nvim_buf_set_keymap(
    0,
    "n",
    "<CR>",
    "<cmd>lua require('neuron_v2.helpers').open_or_create()<CR>",
    {noremap = true, silent = true}
  )

  M.map_buf(m.create_link, "<cmd>lua require('neuron_v2.helpers').create_link()<CR>")

  vim.api.nvim_buf_set_keymap(
    0,
    "v",
    m.create_link,
    ":<C-U>lua require('neuron_v2.helpers').create_link(true)<CR>",
    {noremap = true, silent = true}
  )
  -- M.map_buf("n", "<cmd>lua require'neuron/cmd'.new_edit(v:lua.neuron_v2.config.neuron_dir)<CR>")

  -- M.map_buf("z", "<cmd>lua require'neuron/telescope'.find_zettels()<CR>")
  -- M.map_buf("Z", "<cmd>lua require'neuron/telescope'.find_zettels {insert = true}<CR>")

  -- M.map_buf("b", "<cmd>lua require'neuron/telescope'.find_backlinks()<CR>")
  -- M.map_buf("B", "<cmd>lua require'neuron/telescope'.find_backlinks {insert = true}<CR>")

  M.map_buf("t", "<cmd>lua R('neuron_v2.popup').show_links()<CR>")

  M.map_buf("k", "<cmd>lua require('neuron_v2.telescope').find_zettels()<CR>")
  M.map_buf("K", "<cmd>lua require('neuron_v2.telescope').find_zettels {insert = true}<CR>")
  -- TODO: rename function to start_server
  M.map_buf(m.start_server, "<cmd>lua require('neuron_v2').serve_and_watch({open = true})<CR>")
  M.map_buf(m.open_page, "<cmd>lua require('neuron_v2').open_page()<CR>")
  -- M.map_buf("]", "<cmd>lua require'neuron'.goto_next_extmark()<CR>")
  -- M.map_buf("[", "<cmd>lua require'neuron'.goto_prev_extmark()<CR>")
end

function M.setup()
  vim.cmd(
    string.format("au BufRead %s/**.md lua require('neuron_v2.mappings').set_keymaps()", config.neuron_dir:expand())
  )
  M.map(m.goto_index, "<cmd>lua require('neuron_v2').goto_index()<CR>")
end

return M
