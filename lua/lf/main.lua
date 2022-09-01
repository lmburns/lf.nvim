local M = {}

---@diagnostic disable: redefined-local

local utils = require("lf.utils")
local ctx = require("lf.context")
local log = require("lf.log")

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
local fs = utils.fs
local map = utils.map

local promise = require("promise")
local async = require("async")

---Error for this program
M.error = nil

local Job = require("plenary.job")
local Config = require("lf.config")

-- local with = require("plenary.context_manager").with
-- local open = require("plenary.context_manager").open
-- local a = require("plenary.async_lib")
-- local promise = require("promise")

---@class Terminal
local Terminal = require("toggleterm.terminal").Terminal

---@class Lf
---@field cfg Config Configuration options
---@field term Terminal Toggle terminal
---@field preset_idx number Current index of configuration `presets`
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
            persist_size = true
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
    log.debug("creating a new Lf instance")
    self.__index = self

    if config then
        self.cfg = Config:set(config):get()
    else
        self.cfg = Config
    end

    self.preset_idx = 1
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
                winblend = self.cfg.winblend
            }
        }
    )
end

---Start the underlying terminal
---@param path string path where lf starts (reads from config if none, else CWD)
function Lf:start(path)
    self:__open_in(path or self.cfg.dir):thenCall(
        function()
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
    )
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
---@return Promise
function Lf:__open_in(path)
    ---The whole reason this is async is to make sure that the self
    ---variables have been set and are valid
    return async(
        function()
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
            curr_file = fn.expand("%:p")
        end
    )
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

    -- When using promises, and deferring the entire function, things go a little smoother.
    vim.defer_fn(
        function()
            -- For easier reference
            self.bufnr = term.bufnr
            self.winid = term.window
            vim.cmd("silent doautocmd User LfTermEnter")

            -- Bring into scope.
            -- I believe this prioritizes this asynchronous code since it is needed first
            local cfile = self.curr_file
            -- local curr_file = api.nvim_buf_get_name(fn.bufnr("#"))

            if self.cfg.focus_on_open then
                if self.curr_file == nil then
                    utils.notify(
                        "Function has not been deferred long enough, preventing `focus_on_open` from working.\n" ..
                            "Please report an issue on Github (lmburns/lf.nvim)",
                        utils.levels.WARN
                    )
                elseif term.dir == fs.dirname(self.curr_file) then
                    local base = fs.basename(cfile)

                    utils.readFile(self.id_tmpfile):thenCall(
                        function(d)
                            self.id = tonumber(vim.trim(d))

                            Job:new(
                                {
                                    command = "lf",
                                    args = {
                                        "-remote",
                                        ("send %d select %s"):format(self.id, base)
                                    },
                                    interactive = false,
                                    detached = true,
                                    enabled_recording = false
                                }
                            ):start()
                        end
                    )
                end
            end

            -- Wrap needs to be set, otherwise the window isn't aligned on resize
            api.nvim_win_call(
                self.winid,
                function()
                    vim.wo.showbreak = "NONE"
                    vim.wo.wrap = true
                end
            )

            if self.cfg.tmux then
                utils.tmux(true)
            end

            if self.cfg.mappings then
                if self.cfg.escape_quit then
                    map("t", "<Esc>", "<Cmd>q<CR>", {buffer = self.bufnr, desc = "Exit Lf"})
                end

                for key, mapping in pairs(self.cfg.default_actions) do
                    map(
                        "t",
                        key,
                        function()
                            -- Change default_action for easier reading in the callback
                            self.action = mapping

                            if type(self.id) ~= "number" then
                                utils.readFile(self.id_tmpfile):thenCall(
                                    function(data)
                                        self.id = tonumber(data)
                                    end
                                )
                            end

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
                                utils.get_view(self.cfg.presets[self.preset_idx], self.bufnr, self.signcolumn)
                            )
                            self.preset_idx = self.preset_idx < #self.cfg.presets and self.preset_idx + 1 or 1
                        end
                    )
                end
            end
        end,
        20
    )
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

        utils.readFile(self.lastdir_tmpfile):thenCall(
            function(last_dir)
                if last_dir ~= uv.cwd() then
                    vim.cmd(("%s %s"):format(self.action, last_dir))
                    return
                end
            end
        )
    elseif uv.fs_stat(self.lf_tmpfile) then
        -- TODO: Get this to work asynchronously
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

function M.toggle()
    local winid = ctx.winid()
    if ctx.bufnr() ~= -1 then
        if winid ~= -1 and api.nvim_win_is_valid(winid) then
            if api.nvim_get_current_win() == winid then
                api.nvim_win_close(winid, false)
            else
                api.nvim_set_current_win(winid)
                cmd.startinsert()
            end
        else
        end
    else
        M.init()
    end
end

function M.init(...)
    if ctx.bufnr() ~= -1 then
        return
    end
end

function M.create_lf(cmd, env, background)
end

return M
