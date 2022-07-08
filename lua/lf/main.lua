local M = {}

---@diagnostic disable: redefined-local

local utils = require("lf.utils")

local res, terminal = pcall(require, "toggleterm")
if not res then
    utils.err("toggleterm.nvim must be installed to use this program", true)
    return
end

local res, Path = pcall(require, "plenary.path")
if not res then
    utils.err("plenary must be installed to use this program", true)
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
-- local a = require("plenary.async_lib")
-- local promise = require("promise")

--- @class Terminal
local Terminal = require("toggleterm.terminal").Terminal

---@class Lf
---@field cfg Config Configuration options
---@field term Terminal Toggle terminal
---@field view_idx number Current index of configuration `views`
---@field winid number? `Terminal` window id
---@field lf_tmpfile string File path with the files to open with `lf`
---@field lastdir_tmpfile string File path with the last directory `lf` was in
---@field id_tmpfile? string File path to a file containing `lf`'s id
---@field id number? Current Lf session id
---@field curr_file string|nil File path to the currently opened file
---@field bufnr number The open file's buffer number
---@field action string The current action to open the file
---@field signcolumn string The signcolumn set by the user before the terminal buffer overrides it
local Lf = {}

local function setup_term()
    terminal.setup(
        {
            size = function(term)
                if term.direction == "horizontal" then
                    return o.lines * 0.4
                elseif term.direction == "vertical" then
                    return o.columns * 0.5
                end
            end,
            hide_numbers = true,
            shade_filetypes = {},
            shade_terminals = false,
            shading_factor = "1",
            start_in_insert = true,
            insert_mappings = false,
            persist_size = true,
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
    self.bufnr = 0
    self.id = nil
    self.curr_file = nil
    self.id_tmpfile = nil
    self.action = self.cfg.default_action
    -- Needs to be grabbed here before the terminal buffer is created
    self.signcolumn = o.signcolumn

    setup_term()
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
            highlights = self.cfg.highlights,
            float_opts = {
                border = self.cfg.border,
                width = math.floor(o.columns * self.cfg.width),
                height = math.floor(o.lines * self.cfg.height),
                winblend = self.cfg.winblend,
            }
        }
    )
end

---Start the underlying terminal
---@param path string path where lf starts (reads from config if none, else CWD)
function Lf:start(path)
    self:__open_in(path or self.cfg.dir)
    if M.error ~= nil then
        utils.err(M.error, true)
        return
    end
    self:__wrapper()

    self.term.on_open = function(term)
        self:__on_open(term)
    end

    self.term.on_exit = function(term, _, _, _)
        self:__callback(term)
    end

    self.term:open()
end

---Toggle `Lf` on and off
---@param path string
-- function Lf:toggle(path)
--     -- TODO:
-- end

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
                dir = utils.git_dir()
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
        utils.info("Current file doesn't exist", true)
    end

    -- Should be fine, but just checking
    if not path:is_dir() then
        path = path:parent()
    end

    self.term.dir = path:absolute()
    self.curr_file = fn.expand("%:p")

    return self
end

---@private
---Wrap the default command value to write the selected files to a temporary file
---
---@return Lf
function Lf:__wrapper()
    self.lf_tmpfile = os.tmpname()
    self.lastdir_tmpfile = os.tmpname()
    self.id_tmpfile = os.tmpname()

    -- command lf -command '$printf $id > '"$fid"'' -last-dir-path="$tmp" "$@"

    self.term.cmd =
        ([[%s -command='$printf $id > %s' -last-dir-path='%s' -selection-path='%s' %s]]):format(
        self.term.cmd,
        self.id_tmpfile,
        self.lastdir_tmpfile,
        self.lf_tmpfile,
        self.term.dir
    )
    return self
end

---On open closure to run in the `Terminal`
---@param term Terminal
function Lf:__on_open(term)
    -- For easier reference
    self.bufnr = term.bufnr
    self.winid = term.window
    vim.cmd("silent doautocmd User LfTermEnter")

    -- Wrap needs to be set, otherwise the window isn't aligned on resize
    api.nvim_buf_call(
        self.bufnr,
        function()
            vim.wo[self.winid].showbreak = "NONE"
            vim.wo[self.winid].wrap = true
            -- vim.bo[self.bufnr].ft = ("%s.lf"):format(vim.bo[self.bufnr].ft)
            -- vim.cmd("redraw")
        end
    )

    if self.cfg.tmux then
        utils.tmux(true)
    end

    if self.cfg.mappings and self.cfg.escape_quit then
        map("t", "<Esc>", "<Cmd>q<CR>", {buffer = self.bufnr, desc = "Exit Lf"})
    end

    -- FIX: Asynchronous errors with no access to asynchronous code
    -- Though, toggleterm has no asynchronousity, but plenary does
    -- This will not work without deferring the function
    -- If the module is reloaded via plenary, then re-required and ran it will work
    -- However, if the :Lf command is used, reading the value provides a nil value
    --
    -- Another odd behavior is that if the first line of the function does something like
    -- `vim.notify(("Currfile: '%s'"):format(self.curr_file))`, then the deferring time can be less
    --
    -- Numbers greater than 20 are noticeable
    -- I believe this has to do with the `on_open` callback being asynchronous
    -- If there were to be a way to block the callback until `self.curr_file` was set, this would be fixed
    vim.defer_fn(
        function()
            if self.curr_file == nil then
                utils.notify(
                    "Function has not been deferred long enough, preventing `focus_on_open` from working.\n" ..
                        "Please report an issue on Github (lmburns/lf.nvim)",
                    utils.levels.WARN
                )
                return
            end

            -- local curr_file = api.nvim_buf_get_name(fn.bufnr("#"))

            if self.cfg.focus_on_open and term.dir == fn.fnamemodify(self.curr_file, ":h") then
                local f = assert(io.open(self.id_tmpfile, "r"))
                local data = f:read("*a")
                f:close()

                Job:new(
                    {
                        command = "lf",
                        args = {
                            "-remote",
                            ("send %d select %s"):format(tonumber(data), fn.fnamemodify(self.curr_file, ":t"))
                        },
                        interactive = false,
                        detached = true,
                        enabled_recording = false
                    }
                ):start()
            end
        end,
        25
    )

    if self.cfg.mappings then
        for key, mapping in pairs(self.cfg.default_actions) do
            map(
                "t",
                key,
                function()
                    -- Change default_action for easier reading in the callback
                    self.action = mapping

                    -- FIX: If this is set above, it doesn't seem to work. The value is nil
                    --      There is only a need to read the file once
                    --      Error has to do with the above mentioned on

                    -- ---@cast self.id -?
                    self.id =
                        tonumber(
                        with(
                            open(self.id_tmpfile),
                            function(r)
                                return r:read()
                            end
                        )
                    )
                    -- self.id_tmpfile = nil

                    -- Manually tell `lf` to open the current file
                    -- since Neovim has hijacked the binding
                    Job:new(
                        {
                            command = "lf",
                            args = {"-remote", ("send %d open"):format(self.id)}
                        }
                    ):sync()
                end,
                {noremap = true, buffer = self.bufnr, desc = ("Lf %s"):format(mapping)}
            )
        end

        if self.cfg.layout_mapping then
            map(
                "t",
                self.cfg.layout_mapping,
                function()
                    api.nvim_win_set_config(
                        self.winid,
                        utils.get_view(self.cfg.views[self.view_idx], self.bufnr, self.signcolumn)
                    )
                    self.view_idx = self.view_idx < #self.cfg.views and self.view_idx + 1 or 1
                end
            )
        end
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

    if (self.action == "cd" or self.action == "lcd") and uv.fs_stat(self.lastdir_tmpfile) then
        -- Since plenary is already being used, this is used instead of `io`
        local last_dir =
            with(
            open(self.lastdir_tmpfile),
            function(r)
                return r:read()
            end
        )

        if last_dir ~= uv.cwd() then
            vim.cmd(("%s %s"):format(self.action, last_dir))
            return
        end
    elseif uv.fs_stat(self.lf_tmpfile) then
        local contents = {}

        for line in io.lines(self.lf_tmpfile) do
            table.insert(contents, line)
        end

        if not vim.tbl_isempty(contents) then
            term:close()

            for _, fname in pairs(contents) do
                vim.cmd(("%s %s"):format(self.action, Path:new(fname):absolute()))
            end
        end
    end

    -- Reset the action
    vim.defer_fn(
        function()
            self.action = self.cfg.default_action
        end,
        1
    )
end

M.Lf = Lf

return M
