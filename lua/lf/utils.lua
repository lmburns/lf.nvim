local M = {}

local uv = vim.loop
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
---@param print? boolean
---@param opts table?
function M.info(msg, print, opts)
    if print then
        M.echomsg(("[INFO]: %s"):format(msg), "Directory")
    else
        M.notify(msg, levels.INFO, opts)
    end
end

---WARN message
---@param msg string
---@param print? boolean
---@param opts table?
function M.warn(msg, print, opts)
    if print then
        M.echomsg(("[WARN]: %s"):format(msg), "WarningMsg")
    else
        M.notify(msg, levels.WARN, opts)
    end
end

---ERROR message
---@param msg string
---@param print? boolean
---@param opts table?
function M.err(msg, print, opts)
    if print then
        M.echomsg(("[ERROR]: %s"):format(msg), "ErrorMsg")
    else
        M.notify(msg, levels.ERROR, opts)
    end
end

---Create a shallow copy of a portion of a vector.
---Can index with negative numbers.
---@generic T
---@param vec T[] Vector to select from
---@param first? integer First index, inclusive
---@param last? integer Last index, inclusive
---@return T[] #sliced vector
function M.list_slice(vec, first, last)
    local slice = {}
    if first and first < 0 then
        first = #vec + first + 1
    end
    if last and last < 0 then
        last = #vec + last + 1
    end
    for i = first or 1, last or #vec do
        table.insert(slice, vec[i])
    end

    return slice
end

---Return all elements in `t` between `first` and `last` index.
---Can index with negative numbers.
---@generic T
---@param vec T[] Vector to select from
---@param first? integer First index, inclusive
---@param last? integer Last index, inclusive
---@return T ...
function M.list_select(vec, first, last)
    return unpack(M.list_slice(vec, first, last))
end

---Similar to C's ternary operator
---@generic T, V
---@param cond? boolean|fun():boolean Statement to be tested
---@param is_if T Return if cond is truthy
---@param is_else V Return if cond is not truthy
---@param simple? boolean Never treat `is_if` and `is_else` as arg lists
---@return unknown
function M.tern(cond, is_if, is_else, simple)
    if cond then
        if not simple and type(is_if) == "table" and vim.is_callable(is_if[1]) then
            return is_if[1](M.list_select(is_if, 2))
        end
        return is_if
    else
        if not simple and type(is_else) == "table" and vim.is_callable(is_else[1]) then
            return is_else[1](M.list_select(is_else, 2))
        end
        return is_else
    end
end

---@param path string
---@return uv_fs_t|string
---@return uv.aliases.fs_stat_table?
function M.read_file(path)
    -- tonumber(444, 8) == 292
    local fd = assert(uv.fs_open(fn.expand(path), "r", 292))
    local stat = assert(uv.fs_fstat(fd))
    local buffer = assert(uv.fs_read(fd, stat.size, 0))
    uv.fs_close(fd)
    return buffer, stat
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
        width = width + tonumber(col[2])
    end
    return signcolumn:match("no") and o.columns or o.columns - width
end

---Get the table that is passed to `api.nvim_win_set_config`
---@param opts table
---@param bufnr number Buffer number from the file that Lf is opened from
---@param signcolumn string Signcolumn option set by the user, not the terminal buffer
---@return table
function M.get_view(opts, bufnr, signcolumn)
    opts = opts or {}

    local width = opts.width
        and fn.float2nr(fn.round(opts.width * o.columns))
        or M.width(bufnr, signcolumn)
    local height = opts.height
        and fn.float2nr(fn.round(opts.height * o.lines))
        or M.height()
    local col = opts.col
        and fn.float2nr(fn.round(opts.col * o.columns))
        or math.ceil(o.columns - width) * 0.5 - 1
    local row = opts.row
        and fn.float2nr(fn.round(opts.row * o.lines))
        or math.ceil(o.lines - height) * 0.5 - 1

    return {
        col = col,
        row = row,
        width = width,
        height = height,
        relative = "editor",
        style = "minimal",
    }
end

---Helper function to derive the current git directory path
---@return string|nil
function M.git_dir()
    ---@diagnostic disable-next-line: missing-parameter
    local gitdir = fn.system(("git -C %s rev-parse --show-toplevel"):format(fn.expand("%:p:h")))

    if gitdir:match("^fatal:.*") then
        M.info("Failed to get git directory")
        return
    end
    return vim.trim(gitdir)
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

--  ╭──────────────────────────────────────────────────────────╮
--  │                    vim.fs replacement                    │
--  ╰──────────────────────────────────────────────────────────╯

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
    return fn.fnamemodify(file, ":h")
end

return M
