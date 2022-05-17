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
local o = vim.o
local map = utils.map

---Error for this program
M.error = nil

local Job = require("plenary.job")
local Config = require("lf.config")
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open

--- @class Terminal
local Terminal = require("toggleterm.terminal").Terminal

--- @class Lf
--- @field cfg Config Configuration options
--- @field term Terminal Toggle terminal
--- @field view_idx number Current index of configuration `views`
--- @field winid number `Terminal` window id
--- @field lf_tmp string File path with the files to open with `lf`
--- @field lastdir_tmp string File path with the last directory `lf` was in
--- @field id_tmp string File path to a file containing `lf`'s id
--- @field bufnr number The open file's buffer number
--- @field signcolumn string The signcolumn set by the user before the terminal buffer overrides it
local Lf = {}

local function setup_term(highlights)
    vim.validate({highlights = {highlights, "table", true}})
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
            highlights = highlights
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
    self.__index = self

    if config then
        self.cfg = Config:set(config):get()
    else
        self.cfg = Config
    end

    self.view_idx = 1
    self.winid = nil
    self.id_tmp = nil
    self.bufnr = api.nvim_get_current_buf()
    -- Needed to be grabbed here before the terminal buffer is created
    self.signcolumn = o.signcolumn

    setup_term(self.cfg.highlights)
    self:__create_term()

    return self
end

---Create the toggle terminal
function Lf:__create_term()
    self.term =
        Terminal:new(
        {
            cmd = self.cfg.default_cmd,
            dir = self.cfg.dir,
            direction = self.cfg.direction,
            winblend = self.cfg.winblend,
            close_on_exit = true,
            float_opts = {
                border = self.cfg.border,
                width = math.floor(vim.o.columns * self.cfg.width),
                height = math.floor(vim.o.lines * self.cfg.height),
                winblend = self.cfg.winblend,
                highlights = {border = "Normal", background = "Normal"}
            }
        }
    )
end

---Start the underlying terminal
---@param path string path where lf starts (reads from config if none, else CWD)
function Lf:start(path)
    self:__open_in(path or self.cfg.dir)
    if M.error ~= nil then
        notify(M.error, "error")
        return
    end
    self:__wrapper()

    if self.cfg.mappings then
        self.term.on_open = function(term)
            self:__on_open(term)
        end
    else
        self.term.on_open = function(_)
            self.winid = api.nvim_get_current_win()
            api.nvim_win_set_option(self.winid, "wrap", true)
        end
    end

    self.term.on_exit = function(term, _, _, _)
        self:__callback(term)
    end

    -- NOTE: Maybe pcall here?
    self.term:toggle()
end

---Toggle `Lf` on and off
---@param path string
function Lf:toggle(path)
    -- TODO:
end

---@private
---Set the directory for `Lf` to open in
---
---@param path string
---@return Lf
function Lf:__open_in(path)
    path =
        Path:new(
        (function(dir)
            if dir == "gwd" then
                dir = require("lf.utils").git_dir()
            end

            if dir ~= "" then
                return fn.expand(dir)
            else
                -- Base the CWD on the filename and not `lcd` and such
                return fn.expand("%:p")
            end
        end)(path)
    )

    if not path:exists() then
        utils.info("Current file doesn't exist")
    -- M.error = ("directory doesn't exist: %s"):format(path)
    -- return
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
    self.id_tmp = os.tmpname()

    -- command lf -command '$printf $id > '"$fid"'' -last-dir-path="$tmp" "$@"

    self.term.cmd =
        ([[%s -command='$printf $id > %s' -last-dir-path='%s' -selection-path='%s' %s]]):format(
        self.term.cmd,
        self.id_tmp,
        self.lastdir_tmp,
        self.lf_tmp,
        self.term.dir
    )
    return self
end

-- TODO: Figure out a way to open the file with these commands
---On open closure to run in the `Terminal`
---@param term Terminal
function Lf:__on_open(term)
    -- api.nvim_command("setlocal filetype=lf")

    if self.cfg.tmux then
        utils.tmux(true)
    end

    if self.cfg.escape_quit then
        map("t", "<Esc>", "q", {buffer = term.bufnr})
    end

    for key, mapping in pairs(self.cfg.default_actions) do
        map(
            "t",
            key,
            function()
                -- Change default_action for easier reading in the callback
                self.cfg.default_action = mapping
                -- Set it to a `self` variable in case this is to ever be used again
                self.id =
                    with(
                    open(self.id_tmp),
                    function(r)
                        return r:read()
                    end
                )
                -- self.id_tmp = nil

                -- Manually tell `lf` to open the current file
                -- since Neovim has hijacked the binding
                Job:new(
                    {
                        command = "lf",
                        args = {"-remote", ("send %d open"):format(self.id)}
                    }
                ):sync()
            end,
            {noremap = true, buffer = term.bufnr}
        )
    end

    if self.cfg.layout_mapping then
        self.winid = api.nvim_get_current_win()
        -- Wrap needs to be set, otherwise the window isn't aligned on resize
        api.nvim_win_set_option(self.winid, "wrap", true)

        map(
            "t",
            self.cfg.layout_mapping,
            function()
                api.nvim_win_set_config(
                    self.winid,
                    M.get_view(self.cfg.views[self.view_idx], self.bufnr, self.signcolumn)
                )
                self.view_idx = self.view_idx < #self.cfg.views and self.view_idx + 1 or 1
            end
        )
    end
end

---@private
---A callback for the `Terminal`
---
---@param term Terminal
function Lf:__callback(term)
    if self.cfg.tmux then
        utils.tmux(false)
    end

    if (self.cfg.default_action == "cd" or self.cfg.default_action == "lcd") and uv.fs_stat(self.lastdir_tmp) then
        -- Since plenary is already being used, this is used instead of `io`
        local last_dir =
            with(
            open(self.lastdir_tmp),
            function(r)
                return r:read()
            end
        )

        if last_dir ~= uv.cwd() then
            vim.cmd(("%s %s"):format(self.cfg.default_action, last_dir))
            return
        end
    elseif uv.fs_stat(self.lf_tmp) then
        local contents = {}

        for line in io.lines(self.lf_tmp) do
            table.insert(contents, line)
        end

        if not vim.tbl_isempty(contents) then
            term:close()

            for _, fname in pairs(contents) do
                vim.cmd(("%s %s"):format(self.cfg.default_action, Path:new(fname):absolute()))
            end
        end
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
---@param bufnr number Buffer number from the file that Lf is opened from
---@param signcolumn string Signcolumn option set by the user, not the terminal buffer
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

M.Lf = Lf

return M
