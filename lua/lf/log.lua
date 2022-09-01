---@class LfLogger
---@field trace fun(...)
---@field debug fun(...)
---@field info fun(...)
---@field warn fun(...)
---@field error fun(...)

local M = {}
local fn = vim.fn
local uv = vim.loop

local utils = require("lf.utils")

---@enum level_map
local level_map
local level_nr
local default_level

---Get the log level number
---@param level string|number
---@return number
local function get_level_nr(level)
    local nr
    local t = type(level)
    if t == "number" then
        nr = level
    elseif t == "string" then
        nr = level_map[level:upper()]
    else
        nr = default_level
    end
    return nr
end

---Set the log level
---@param lvl number|string
function M.set_level(lvl)
    level_nr = get_level_nr(lvl)
end

---Check whether a given log level is enabled
---@param lvl string|number
---@return boolean
function M.is_enabled(lvl)
    return get_level_nr(lvl) >= level_nr
end

---Return the log level
---@return string
function M.level()
    for l, nr in pairs(level_map) do
        if nr == level_nr then
            return l
        end
    end
    return "UNDEFINED"
end

---Inspect the given value
---@param v any
---@return string?
local function inspect(v)
    local s
    local t = type(v)
    if t == "nil" then
        s = "nil"
    elseif t == "userdata" then
        s = ("Userdata:\n%s"):format(vim.inspect(getmetatable(v)))
    elseif t ~= "string" then
        s = vim.inspect(v, {depth = math.huge, indent = "", newline = " "})
    else
        s = tostring(v)
    end
    return s
end

---Return the correct path separator
---@return string
local function path_sep()
    local is_windows = uv.os_uname().sysname == "Windows_NT"
    return (is_windows and not vim.o.shellslash) and [[\]] or "/"
end

local function init()
    local log_dir = fn.stdpath("cache")
    local log_file = table.concat({log_dir, "lf.log"}, path_sep())
    local log_date_fmt = "%y-%m-%d %T"

    fn.mkdir(log_dir, "p")
    level_map = {TRACE = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4}
    default_level = 3
    M.set_level(vim.env.LFVIM_LOG)

    for l in pairs(level_map) do
        M[l:lower()] = function(...)
            local argc = select("#", ...)
            if argc == 0 or level_map[l] < level_nr then
                return
            end
            local msg_tbl = {}
            for i = 1, argc do
                local arg = select(i, ...)
                table.insert(msg_tbl, inspect(arg))
            end
            local msg = table.concat(msg_tbl, " ")
            local info = debug.getinfo(2, "Sl")
            local linfo = info.short_src:match("[^/]*$") .. ":" .. info.currentline

            local str = ("[%s] [%s] %s : %s\n"):format(os.date(log_date_fmt), l, linfo, msg)
            utils.appendFile(log_file, str)

            -- local fp = assert(io.open(log_file, "a+"))
            -- fp:write(str)
            -- fp:close()
        end
    end
end

init()

return M
