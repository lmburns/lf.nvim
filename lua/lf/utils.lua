local M = {}

-- This was taken from toggleterm.nvim

local fn = vim.fn
local api = vim.api
local fmt = string.format
local levels = vim.log.levels

---Echo a message with `nvim_echo`
---@param msg string message
---@param hl string highlight group
M.echomsg = function(msg, hl)
  hl = hl or "Title"
  api.nvim_echo({ { msg, hl } }, true, {})
end

---Display an info message on the CLI
---@param msg string
M.info = function(msg)
  M.echomsg(("[INFO]: %s"):format(msg), "Directory")
  -- M.echomsg(("[INFO]: %s"):format(msg), "Identifier")
end

---Display a warning message on the CLI
---@param msg string
M.warn = function(msg)
  M.echomsg(("[WARN]: %s"):format(msg), "WarningMsg")
end

---Display an error message on the CLI
---@param msg string
M.err = function(msg)
  M.echomsg(("[ERR]: %s"):format(msg), "ErrorMsg")
end

---Display notification message
---@param msg string
---@param level 'error' | 'info' | 'warn'
M.notify = function(msg, level)
  level = level and levels[level:upper()] or levels.INFO
  vim.notify(fmt("[lf]: %s", msg), level)
end

---Helper function to derive the current git directory path
---@return string|nil
M.git_dir = function()
  local gitdir = fn.system(
      fmt(
          "git -C %s rev-parse --show-toplevel", fn.expand("%:p:h")
      )
  )

  local isgitdir = fn.matchstr(gitdir, "^fatal:.*") == ""
  if not isgitdir then
    return
  end
  return vim.trim(gitdir)
end

M.map = function(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap == nil and true or opts.noremap
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
