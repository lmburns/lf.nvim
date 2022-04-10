local M = {}

---@diagnostic disable: redefined-local

local utils = require("lf.utils")
local notify = utils.notify

local res, terminal = pcall(require, "toggleterm")
if not res then
  notify("toggleterm.nvim must be installed to use this program", "error")
  return
end

local res, Path = pcall(require, "plenary.path")
if not res then
  notify("plenary must be installed to use this program", "error")
  return
end

local api = vim.api
local fn = vim.fn
local uv = vim.loop
local g = vim.g
local map = utils.map

---Error for this program
ERROR = nil
---Global running status
---I'm unsure of a way to keep an `Lf` variable constant through more than 1 `setup` calls
g.__lf_running = false

local Config = require("lf.config")

--- @class Terminal
local Terminal = require("toggleterm.terminal").Terminal

--- @class Lf
--- @field cmd string
--- @field direction string the layout style for the terminal
--- @field id number
--- @field window number
--- @field job_id number
--- @field highlights table<string, table<string, string>>
local Lf = {}

local function setup_term()
  terminal.setup(
      {
        size = function(term)
          if term.direction == "horizontal" then
            return vim.o.lines * 0.4
          elseif term.direction == "vertical" then
            return vim.o.columns * 0.5
          end
        end,
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = "1",
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        -- open_mapping = [[<c-\>]],
      }
  )
end

---Setup a new instance of `Lf`
---Configuration has not been fully parsed by the end of this function
---A `Terminal` becomes attached and is able to be toggled
---
---@param config 'table'
---@return Lf
function Lf:new(config)
  local cfg = Config:set(config):get()
  self.__index = self

  self.cfg = cfg
  self.cwd = uv.cwd()

  setup_term()
  self.term = Terminal:new(
      {
        cmd = cfg.default_cmd,
        dir = cfg.dir,
        direction = cfg.direction,
        winblend = cfg.winblend,
        close_on_exit = true,

        float_opts = {
          border = cfg.border,
          width = math.floor(vim.o.columns * cfg.width),
          height = math.floor(vim.o.lines * cfg.height),
          winblend = cfg.winblend,
          highlights = { border = "Normal", background = "Normal" },
        },

        -- on_open = cfg.on_open,
        -- on_close = nil,
      }
  )

  return self
end

---Start the underlying terminal
---@param path string path where lf starts (reads from config if none, else CWD)
function Lf:start(path)
  self:__open_in(path or self.cfg.dir)
  if ERROR ~= nil then
    notify(ERROR, "error")
    return
  end
  self:__wrapper()

  self.term.on_open = function(term)
    self:__on_open(term)
  end

  self.term.on_exit = function(term, _, _, _)
    self:__callback(term)
  end

  -- NOTE: Maybe pcall here?
  self.term:toggle()
  g.__lf_running = true
end

function Lf:toggle(path)
  print(g.__lf_running)
  if g.__lf_running then
    self.term:close()
    g.__lf_running = false
  else
    self:start(path)
  end
end

---@private
---Set the directory for `Lf` to open in
---
---@param path string
---@return Lf
function Lf:__open_in(path)
  path = Path:new(
      (function(dir)
        if dir == "gwd" then
          dir = require("lf.utils").git_dir()
        end

        if dir then
          return fn.expand(dir)
        else
          return self.cwd
        end
      end)(path)
  )

  if not path:exists() then
    ERROR = ("directory doesn't exist: %s"):format(path)
    return
  end

  -- Should be fine, but just checking
  if not path:is_dir() then
    path = path:parent()
  end

  self.term.dir = path:absolute()

  return self
end

---@private
---Wrap the default command value to write the selected files to a temporary file
---
---@return Lf
function Lf:__wrapper()
  self.lf_tmp = os.tmpname()
  self.lastdir_tmp = os.tmpname()

  self.term.cmd = ([[%s -last-dir-path='%s' -selection-path='%s' %s]]):format(
      self.term.cmd, self.lastdir_tmp, self.lf_tmp, self.term.dir
  )
  return self
end

-- TODO: Figure out a way to open the file with these commands
---On open closure to run in the `Terminal`
---@param term Terminal
function Lf:__on_open(term)
  for key, mapping in pairs(self.cfg.default_actions) do
    map(
        "t", key, function()
          self.cfg.default_action = mapping
          notify(("Default action changed: %s"):format(mapping))
        end, { noremap = true, buffer = term.bufnr }
    )
  end
end

---@private
---A callback for the `Terminal`
---
---@param term Terminal
function Lf:__callback(term)
  if (self.cfg.default_action == "cd" or self.cfg.default_action == "lcd") and
      uv.fs_stat(self.lastdir_tmp) then
    local f = io.open(self.lastdir_tmp)
    local last_dir = f:read()
    f:close()

    if last_dir ~= uv.cwd() then
      api.nvim_exec(("%s %s"):format(self.cfg.default_action, last_dir), true)
      return
    end
  elseif uv.fs_stat(self.lf_tmp) then
    local contents = {}

    for line in io.lines(self.lf_tmp) do
      contents[#contents + 1] = line
    end

    if not vim.tbl_isempty(contents) then
      term:close()

      for _, fname in pairs(contents) do
        api.nvim_exec(
            ("%s %s"):format(
                self.cfg.default_action, Path:new(fname):absolute()
            ), true
        )
      end
    end
  end
end

M.Lf = Lf

return M
