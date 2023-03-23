local M = {}

---@diagnostic disable: redefined-local

local utils = require("lf.utils")

local res, terminal = pcall(require, "toggleterm")
if not res then
    utils.err("toggleterm.nvim must be installed to use this program")
    return
end

local res, Path = pcall(require, "plenary.path")
if not res then
    utils.err("plenary must be installed to use this program")
    return
end

local cmd = vim.cmd
local api = vim.api
local fn = vim.fn
local uv = vim.loop
local o = vim.o
local fs = utils.fs
local map = utils.map

---Error for this program
M.error = nil

local Config = require("lf.config")
local a = require("plenary.async")
local autil = require("plenary.async.util")
local Job = require("plenary.job")
-- local promise = require("promise")

---@class Terminal
local Terminal = require("toggleterm.terminal").Terminal

---@class Lf
---@field cfg LfConfig Configuration options
---@field term Terminal toggleterm terminal
---@field view_idx number Current index of configuration `views`
---@field winid? number `Terminal` window id
---@field curr_file? string File path of the currently opened file
---@field id_tf? string Path to a file containing `lf`'s id
---@field selection_tf string Path to a file containing `lf`'s selection(s)
---@field lastdir_tf string Path to a file containing the last directory `lf` was in
---@field id number? Current `lf` session id
---@field bufnr number The open file's buffer number
---@field action string The current action to open the file
---@field signcolumn string The signcolumn set by the user before the terminal buffer overrides it
local Lf = {}

---@private
---Setup `toggleterm`'s `Terminal`
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
            start_in_insert = true,
            insert_mappings = false,
            terminal_mappings = true,
            persist_mode = false,
            persist_size = false
        }
    )
end

---Setup a new instance of `Lf`
---Configuration has not been fully parsed by the end of this function
---A `Terminal` becomes attached and is able to be toggled
---
---@param config? LfConfig
---@return Lf
function Lf:new(config)
    self.__index = self

    if config then
        self.cfg = Config:set(config):get()
    else
        self.cfg = Config
    end

    self.id = nil
    self.bufnr = 0
    self.winid = nil
    self.view_idx = 1

    self.curr_file = nil
    self.id_tf = nil
    self.selection_tf = nil
    self.lastdir_tf = nil

    self.action = self.cfg.default_action
    -- Needs to be grabbed here before the terminal buffer is created
    self.signcolumn = o.signcolumn

    setup_term()
    self:__create_term()

    return self
end

---@private
---Create the `Terminal` and set it o `Lf.term`
function Lf:__create_term()
    self.term = Terminal:new(
        {
            cmd = self.cfg.default_cmd,
            dir = self.cfg.dir,
            direction = self.cfg.direction,
            winblend = self.cfg.winblend,
            close_on_exit = true,
            hidden = false,
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
---@param path? string path where Lf starts (reads from Config if none, else CWD)
function Lf:start(path)
    self:__open_in(path or self.cfg.dir)
    if M.error ~= nil then
        utils.err(M.error)
        return
    end
    self:__set_cmd_wrapper()

    self.term.on_open = function(term)
        a.run(
            function()
                self:__on_open(term)
            end
        )
    end

    self.term.on_exit = function(term, _, _, _)
        self:__callback(term)
    end

    self.term:open()
end

---@private
---Set the directory for `Lf` to open in
---
---@param path? string
---@return Lf?
function Lf:__open_in(path)
    local built = Path:new(
        (function(dir)
            if dir == "gwd" or dir == "git_dir" then
                dir = utils.git_dir()
            end

            -- Base the CWD on the filename and not `lcd` and such
            return fn.expand(utils.tern(dir == "" or dir == nil, "%:p:h", dir))
        end)(path)
    )

    if not built:exists() then
        utils.warn("Current directory doesn't exist")
        return
    end

    -- Should be fine, but just checking
    if not built:is_dir() then
        built = built:parent()
    end

    self.term.dir = built:absolute()
    self.curr_file = fn.expand("%:p")

    return self
end

---@private
---Wrap the default command to write the selected files to a temporary file
---
---@return Lf
function Lf:__set_cmd_wrapper()
    self.selection_tf = os.tmpname()
    self.lastdir_tf = os.tmpname()
    self.id_tf = os.tmpname()

    -- command lf -command '$printf $id > '"$fid"'' -last-dir-path="$tmp" "$@"
    self.term.cmd =
        ([[%s -command='$printf $id > %s' -last-dir-path='%s' -selection-path='%s' %s]]):format(
            self.term.cmd, self.id_tf, self.lastdir_tf, self.selection_tf,
            self.term.dir
        )
    return self
end

---@private
---On open closure to run in the `Terminal`
---@param term Terminal
function Lf:__on_open(term)
    -- For easier reference
    self.bufnr = term.bufnr
    self.winid = term.window

    -- TODO: The delay here needs to be fixed.
    --       I need to find a way to block this outer function's caller
    vim.defer_fn(
        function()
            if self.cfg.focus_on_open then
                if self.curr_file == nil then
                    utils.warn(
                        "Function has not been deferred long enough, preventing `focus_on_open` from working.\n"
                            .. "Please report an issue on Github (lmburns/lf.nvim)"
                    )
                    return
                end

                if term.dir == fs.dirname(self.curr_file) then
                    if not fn.filereadable(self.id_tf) then
                        utils.err(
                            ("Lf's id file is not readable: %s"):format(
                                self.id_tf
                            )
                        )
                        return
                    end

                    local res = utils.read_file(self.id_tf)
                    self.id = tonumber(res)

                    if self.id == nil then
                        utils.warn(
                            "Lf's ID was not set\n"
                                .. "Please report an issue on Github (lmburns/lf.nvim)"
                        )
                        return
                    end
                    Job:new(
                        {
                            command = "lf",
                            args = {
                                "-remote",
                                ("send %s select %s"):format(
                                    self.id, fs.basename(self.curr_file)
                                )
                            },
                            interactive = false,
                            detached = true,
                            enabled_recording = false
                        }
                    ):sync()
                end
            end
        end, 75
    )

    cmd("silent doautocmd User LfTermEnter")

    -- Wrap needs to be set, otherwise the window isn't aligned on resize
    api.nvim_buf_call(
        self.bufnr, function()
            vim.wo[self.winid].showbreak = "NONE"
            vim.wo[self.winid].wrap = true
        end
    )

    if self.cfg.tmux then
        utils.tmux(true)
    end

    -- Not sure if this works
    autil.scheduler(
        function()
            if self.cfg.mappings then
                if self.cfg.escape_quit then
                    map(
                        "t", "<Esc>", "<Cmd>q<CR>",
                        {
                            buffer = self.bufnr,
                            desc = "Exit Lf"
                        }
                    )
                end

                for key, mapping in pairs(self.cfg.default_actions) do
                    map(
                        "t", key, function()
                            -- Change default_action for easier reading in the callback
                            self.action = mapping

                            -- Manually tell `lf` to open the current file
                            -- since Neovim has hijacked the binding
                            Job:new(
                                {
                                    command = "lf",
                                    args = {
                                        "-remote",
                                        ("send %d open"):format(self.id)
                                    }
                                }
                            ):sync()
                        end, {
                            noremap = true,
                            buffer = self.bufnr,
                            desc = ("Lf %s"):format(mapping)
                        }
                    )
                end

                if self.cfg.layout_mapping then
                    map(
                        "t", self.cfg.layout_mapping, function()
                            api.nvim_win_set_config(
                                self.winid, utils.get_view(
                                    self.cfg.views[self.view_idx], self.bufnr,
                                    self.signcolumn
                                )
                            )
                            self.view_idx = self.view_idx < #self.cfg.views
                                                and self.view_idx + 1 or 1
                        end
                    )
                end
            end
        end
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

    if (self.action == "cd" or self.action == "lcd")
        and uv.fs_stat(self.lastdir_tf) then
        local last_dir = utils.read_file(self.lastdir_tf)

        if last_dir ~= nil and last_dir ~= uv.cwd() then
            cmd(("%s %s"):format(self.action, last_dir))
            return
        end
    elseif uv.fs_stat(self.selection_tf) then
        local contents = {}

        for line in io.lines(self.selection_tf) do
            table.insert(contents, line)
        end

        if not vim.tbl_isempty(contents) then
            term:close()

            for _, fname in pairs(contents) do
                cmd(("%s %s"):format(self.action, Path:new(fname):absolute()))
            end
        end
    end

    -- Reset the action
    vim.defer_fn(
        function()
            self.action = self.cfg.default_action
        end, 1
    )
end

M.Lf = Lf

return M
