local M = {}

local fn = vim.fn
local api = vim.api
local levels = vim.log.levels
local o = vim.o

---Echo a message with `nvim_echo`
---@param msg string message
---@param hl string highlight group
function M.echomsg(msg, hl)
    hl = hl or "Title"
    api.nvim_echo({{msg, hl}}, true, {})
end

---Display notification message
---@param msg string
---@param level number
---@param opts table?
function M.notify(msg, level, opts)
    opts = vim.tbl_extend("force", opts or {}, {title = "lf.nvim"})
    vim.notify(msg, level, opts)
end

---INFO message
---@param msg string
---@param notify boolean?
---@param opts table?
function M.info(msg, notify, opts)
    if notify then
        M.notify(msg, levels.INFO, opts)
    else
        M.echomsg(("[INFO]: %s"):format(msg), "Directory")
    end
end

---WARN message
---@param msg string
---@param notify boolean?
---@param opts table?
function M.warn(msg, notify, opts)
    if notify then
        M.notify(msg, levels.WARN, opts)
    else
        M.echomsg(("[WARN]: %s"):format(msg), "WarningMsg")
    end
end

---ERROR message
---@param msg string
---@param notify boolean?
---@param opts table?
function M.err(msg, notify, opts)
    if notify then
        M.notify(msg, levels.ERROR, opts)
    else
        M.echomsg(("[ERR]: %s"):format(msg), "ErrorMsg")
    end
end

---Helper function to derive the current git directory path
---@return string|nil
function M.git_dir()
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
---@param rhs string|function string or lua function that is mapped to the keys
---@param opts table? options set for the mapping
function M.map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    vim.keymap.set(mode, lhs, rhs, opts)
end

---Set the tmux statusline when opening/closing `Lf`
---@param disable boolean: whether the statusline is being enabled or disabled
function M.tmux(disable)
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

---Simple rounding function
---@param num number number to round
---@return number
function M.round(num)
    return math.floor(num + 0.5)
end

---Get Neovim window height
---@return number
function M.height()
    return o.lines - o.cmdheight
end

---Get neovim window width (minus signcolumn)
---@param bufnr number: Buffer number from the file that Lf is opened from
---@param signcolumn string: Signcolumn option set by the user, not the terminal buffer
---@return number
function M.width(bufnr, signcolumn)
    -- This is a rough estimate of the signcolumn
    local width = #tostring(api.nvim_buf_line_count(bufnr))
    local col = vim.split(signcolumn, ":")
    if #col == 2 then
        -- Can't cast integer to number?
        ---@diagnostic disable-next-line:cast-local-type
        width = width + tonumber(col[2])
    end
    ---@diagnostic disable-next-line:return-type-mismatch
    return signcolumn:match("no") and o.columns or o.columns - width
end

---Get the table that is passed to `api.nvim_win_set_config`
---@param opts table
---@param bufnr number Buffer number from the file that Lf is opened from
---@param signcolumn string Signcolumn option set by the user, not the terminal buffer
---@return table
function M.get_view(opts, bufnr, signcolumn)
    opts = opts or {}
    local width =
        opts.width or math.ceil(math.min(M.width(bufnr, signcolumn), math.max(80, M.width(bufnr, signcolumn) - 20)))
    local height = opts.height or math.ceil(math.min(M.height(), math.max(20, M.height() - 10)))

    width = fn.float2nr(width * M.width(bufnr, signcolumn))
    height = fn.float2nr(M.round(height * M.height()))
    local col = fn.float2nr(M.round((M.width(bufnr, signcolumn) - width) / 2))
    local row = fn.float2nr(M.round((M.height() - height) / 2))

    return {
        col = col,
        row = row,
        relative = "editor",
        style = "minimal",
        width = width,
        height = height
    }
end

M.fs = {}

---Return basename of the given file entry
---
---@param file string: File or directory
---@return string: Basename of `file`
function M.fs.basename(file)
    return fn.fnamemodify(file, ":t")
end

---Return parent directory of the given file entry
---
---@param file string: File or directory
---@return string?: Parent directory of file
function M.fs.dirname(file)
  if file == nil then
    return nil
  end
  return fn.fnamemodify(file, ':h')
end

return M
