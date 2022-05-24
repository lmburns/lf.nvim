local M = {}

-- This was taken from toggleterm.nvim

local fn = vim.fn
local api = vim.api
local levels = vim.log.levels

---Echo a message with `nvim_echo`
---@param msg string message
---@param hl string highlight group
M.echomsg = function(msg, hl)
    hl = hl or "Title"
    api.nvim_echo({{msg, hl}}, true, {})
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
    ---@diagnostic disable-next-line: undefined-field
    level = level and levels[level:upper()] or levels.INFO
    vim.notify(("[lf]: %s"):format(msg), level)
end

---Helper function to derive the current git directory path
---@return string|nil
M.git_dir = function()
    ---@diagnostic disable-next-line: missing-parameter
    local gitdir = fn.system(("git -C %s rev-parse --show-toplevel"):format(fn.expand("%:p:h")))

    local isgitdir = fn.matchstr(gitdir, "^fatal:.*") == ""
    if not isgitdir then
        return
    end
    return vim.trim(gitdir)
end

---Create a neovim keybinding
---@param mode string vim mode in a single letter
---@param lhs string keys that are bound
---@param rhs string string or lua function that is mapped to the keys
---@param opts table? options set for the mapping
M.map = function(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    vim.keymap.set(mode, lhs, rhs, opts)

    local ok, wk = pcall(require, "which-key")
    if ok and opts.desc then
        wk.register(
            {
                [lhs] = opts.desc
            },
            {mode = mode}
        )
    end
end

---Set the tmux statusline when opening/closing `Lf`
---@param disable boolean: whether the statusline is being enabled or disabled
M.tmux = function(disable)
    if not vim.env.TMUX then
        return
    end
    if disable then
        fn.system([[tmux set status off]])
        fn.system([[tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z]])
    else
        fn.system([[tmux set status on]])
        fn.system([[tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z]])
    end
end

return M
