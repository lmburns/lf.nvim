local M = {}
local loaded = false

local utils = require("lf.utils")

---Check Neovim version before setting mappings
---@param cfg LfConfig
local function has_feature(cfg)
    if not vim.keymap or not vim.keymap.set then
        utils.err("lf.nvim mappings require Neovim 0.7.0 or higher", true)
        cfg.mappings = false
    end
end

---Setup the Lf plugin
---@param cfg LfConfig
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
---@param cfg LfConfig
function M.start(path, cfg)
    local path_t = type(path)

    -- Only one argument was given
    -- `path` is given as a table, which is treated as `cfg`
    if path ~= nil and cfg == nil and path_t == "table" then
        require("lf.main").Lf:new(path or M._cfg):start(nil)
    else
        -- Strict nil checks are needed because `nil` can be given as an argument
        if path ~= nil and path_t ~= "string" then
            utils.err("first argument must be a string")
            return
        end
        if cfg ~= nil and type(cfg) ~= "table" then
            utils.err("second argument must be a table")
            return
        end

        require("lf.main").Lf:new(cfg or M._cfg):start(path)
    end
end

return M
