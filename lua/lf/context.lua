local M = {}

local bufnr = -1
local winid = -1

function M.bufnr(...)
    local args = {...}
    local old = bufnr
    if args[1] == 1 then
        bufnr = args[2]
    end
    return old
end

function M.winid(...)
    local args = {...}
    local old = winid
    if args[1] == 1 then
        winid = args[2]
    end
    return old
end

return M
