local M = {}
local loaded = false

local utils = require("lf.utils")

local function has_feature(cfg)
    if not vim.keymap or not vim.keymap.set then
        utils.err("lf.nvim mappings require Neovim 0.7.0 or higher", true)
        cfg.mappings = false
    end
end

function M.setup(cfg)
    if loaded then
        return
    end

    has_feature(cfg)
    M._cfg = cfg or {}
    loaded = true
end

---Start the file manager
---`nil` can be used as the first parameter to change options and open in CWD
---
---@param path string optional path to start in
function M.start(path, cfg)
    -- Only one argument was given

    if path and cfg == nil and type(path) == "table" then
        require("lf.main").Lf:new(path or M._cfg):start(nil)
    else
        if cfg ~= nil and type(path) ~= "string" then
            utils.err("first argument must be a string", true)
            return
        end
        if cfg ~= nil and type(cfg) ~= "table" then
            utils.err("second argument must be a table", true)
            return
        end

        require("lf.main").Lf:new(cfg or M._cfg):start(path)
    end
end

return M
