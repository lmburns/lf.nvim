local M = {}

local Config = require("lf.config")
local utils = require("lf.utils")

local uv = vim.loop
local api = vim.api
local fn = vim.fn

---Check Neovim version before setting mappings
---@param cfg Lf.Config
local function has_feature(cfg)
    if not vim.keymap or not vim.keymap.set then
        utils.err("lf.nvim mappings require Neovim 0.7.0 or higher", true)
        cfg.mappings = false
    end
end

---Make `Lf` become the file manager that opens whenever a directory buffer is loaded
---@param bufnr integer
---@return boolean
local function become_dir_fman(bufnr)
    local bufname = api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        return false
    end
    local stat = uv.fs_stat(bufname)
    if type(stat) ~= "table" or (type(stat) == "table" and stat.type ~= "directory") then
        return false
    end

    return true
end

local function setup_autocmds()
    api.nvim_create_user_command("Lf", function(tbl)
        require("lf").start(tbl.args)
    end, {nargs = "*", complete = "file"})

    if Config.data.default_file_manager or vim.g.lf_netrw then
        local group = api.nvim_create_augroup("Lf_ReplaceNetrw", {clear = true})

        if vim.g.loaded_netrwPlugin ~= 1 and not Config.data.disable_netrw_warning then
            api.nvim_create_autocmd("FileType", {
                desc = "Display message about Lf not being default file manager",
                group = group,
                pattern = "netrw",
                once = true,
                callback = function()
                    utils.warn([[Lf cannot be the default file manager with netrw enabled.]] ..
                        [[Put `vim.g.loaded_netrwPlugin` in your configuration.]])
                end,
            })
        end

        api.nvim_create_autocmd("VimEnter", {
            desc = "Override the default file manager (i.e., netrw)",
            group = group,
            pattern = "*",
            nested = true,
            callback = function(a)
                if fn.exists("#FileExplorer") then
                    api.nvim_create_augroup("FileExplorer", {clear = true})
                end
            end,
        })

        api.nvim_create_autocmd("BufEnter", {
            desc = "After overriding default file manager, open Lf",
            group = group,
            pattern = "*",
            once = true,
            callback = function(a)
                if become_dir_fman(a.buf) then
                    vim.defer_fn(function()
                        require("lf").start(a.file)
                    end, 1)
                end
            end,
        })
    end
end

---Setup the Lf plugin
---@param cfg Lf.Config
function M.setup(cfg)
    if Config.__loaded then
        return
    end

    cfg = cfg or {}
    has_feature(cfg)
    M.__conf = cfg
    Config.init()
    setup_autocmds()
end

---Start the file manager
---`nil` can be used as the first parameter to change options and open in CWD
---@param path? string optional path to start in
---@param cfg? Lf.Config alternative configuration options
---@overload fun(cfg: Lf.Config)                   Only a config
---@overload fun(path: string)                    Only a path
---@overload fun(path: string, cfg: Lf.Config)     Path and config are both valid
---@overload fun(path: nil, cfg: Lf.Config)        Explicit nil to provide a config
---@overload fun()                                Empty
function M.start(path, cfg)
    local path_t = type(path)
    local Lf = require("lf.main")

    -- Only one argument was given
    -- `path` is given as a table, which is treated as `cfg`
    if path ~= nil and cfg == nil and path_t == "table" then
        Lf:new(path or M.__conf):start(nil)
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

        local opts = vim.tbl_deep_extend("keep", cfg or {}, Config.data)
        Lf:new(cfg or M.__conf):start(path)
    end
end

return M
