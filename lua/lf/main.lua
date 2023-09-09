local utils = require("lf.utils")

local ok, terminal = pcall(require, "toggleterm")
if not ok then
    utils.err("toggleterm.nvim must be installed to use this program")
    return
end

local cmd = vim.cmd
local api = vim.api
local fn = vim.fn
local uv = vim.loop
local o = vim.o
local fs = utils.fs
local map = utils.map

local Config = require("lf.config")
-- local promise = require("promise")
-- local async = require("async")

---@class Terminal
local Terminal = require("toggleterm.terminal").Terminal

---@class Lf
---@field cfg Lf.Config Configuration options
---@field term Terminal toggleterm terminal
---@field view_idx number Current index of configuration `views`
---@field winid? number `Terminal` window id
---@field curfile? string File path of the currently opened file
---@field tmp_id? string Path to a file containing `lf`'s id
---@field tmp_sel string Path to a file containing `lf`'s selection(s)
---@field tmp_lastdir string Path to a file containing the last directory `lf` was in
---@field id number? Current `lf` session id
---@field bufnr number The open file's buffer number
---@field arglist string[] The argument list to neovim
---@field action string The current action to open the file
---@field signcolumn string The signcolumn set by the user before the terminal buffer overrides it
local Lf = {}
Lf.__index = Lf

---@private
---Setup `toggleterm`'s `Terminal`
local function setup_term()
    terminal.setup({
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
        persist_size = false,
    })
end

---Setup a new instance of `Lf`
---Configuration has not been fully parsed by the end of this function
---A `Terminal` becomes attached and is able to be toggled
---@param config? Lf.Config
---@return Lf
function Lf:new(config)
    if config then
        self.cfg = Config:override(config)
    else
        self.cfg = Config.data
    end

    self:__set_argv()
    self.bufnr = 0
    self.view_idx = 1
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
    self.term = Terminal:new({
        cmd = self.cfg.default_cmd,
        dir = self.cfg.dir,
        direction = self.cfg.direction,
        winblend = self.cfg.winblend,
        close_on_exit = true,
        hidden = false,
        clear_env = self.cfg.env.clear,
        highlights = self.cfg.highlights,
        display_name = "Lf",
        count = self.cfg.count,
        float_opts = {
            border = self.cfg.border,
            width = self.cfg.width,
            height = self.cfg.height,
            winblend = self.cfg.winblend,
        },
    })
end

---Start the underlying terminal
---@param path? string path where `Lf` starts (reads from `Config` if none, else CWD)
function Lf:start(path)
    self:__open_in(path or self.cfg.dir)
    self:__set_cmd_wrapper()

    self.term.on_open = function(term)
        self:__on_open(term)
    end

    self.term.on_exit = function(term, _, _, _)
        self:__callback(term)
        uv.fs_unlink(self.tmp_id)
        uv.fs_unlink(self.tmp_lastdir)
        uv.fs_unlink(self.tmp_sel)
    end

    self.term:open()
end

---@private
---Set the directory for `Lf` to open in
---@param path? string
---@return Lf?
function Lf:__open_in(path)
    if path == "gwd" or path == "git_dir" then
        path = utils.git_dir()
    end
    path = fn.expand((path == "" or path == nil) and "%:p:h" or path)

    local built = path
    local stat = uv.fs_stat(path)
    if not type(stat) == "table" then
        local cwd = uv.cwd()
        stat = uv.fs_stat(cwd)
        built = cwd
    end

    -- Should be fine, but just checking
    if stat and not stat.type == "directory" then
        built = fs.dirname(built)
    end

    self.term.dir = built
    self.curfile = fn.expand("%:p")

    return self
end

---@private
---Wrap the default command to write the selected files to a temporary file
---@return Lf
function Lf:__set_cmd_wrapper()
    self.tmp_sel = os.tmpname()
    self.tmp_lastdir = os.tmpname()
    self.tmp_id = os.tmpname()

    local open_on = self.term.dir
    if
        self.cfg.focus_on_open
        and fs.dirname(self.curfile) == self.term.dir
    then
        open_on = self.curfile
    end

    -- command lf -command '$printf $id > '"$fid"'' -last-dir-path="$tmp" "$@"
    self.term.cmd =
        ([[%s -command='$printf $id > %s' -last-dir-path='%s' -selection-path='%s' '%s']])
        :format(
            self.term.cmd,
            self.tmp_id,
            self.tmp_lastdir,
            self.tmp_sel,
            open_on
        )
    return self
end

---@private
---On open closure to run in the `Terminal`
---@param term Terminal
function Lf:__on_open(term)
    self.bufnr = term.bufnr
    self.winid = term.window

    cmd("silent! doautocmd User LfTermEnter")

    -- Wrap needs to be set, otherwise the window isn't aligned on resize
    api.nvim_win_call(self.winid, function()
        vim.wo.showbreak = "NONE"
        vim.wo.wrap = true
        vim.wo.sidescrolloff = 0
        vim.wo.scrolloff = 0
        vim.wo.scrollbind = false
    end)

    if self.cfg.tmux then
        utils.tmux(true)
    end

    -- Not sure if this works
    if self.cfg.mappings then
        if self.cfg.escape_quit then
            map(
                "t",
                "<Esc>",
                "<Cmd>q<CR>",
                {buffer = self.bufnr, desc = "Exit Lf"}
            )
        end

        for key, mapping in pairs(self.cfg.default_actions) do
            map("t", key, function()
                -- Change default_action for easier reading in the callback
                self.action = mapping

                local res = utils.read_file(self.tmp_id)
                self.id = tonumber(res)

                fn.system({"lf", "-remote", ("send %d open"):format(self.id)})
            end, {noremap = true, buffer = self.bufnr, desc = ("Lf %s"):format(mapping)})
        end

        if self.cfg.layout_mapping then
            map("t", self.cfg.layout_mapping, function()
                api.nvim_win_set_config(self.winid, utils.get_view(
                    self.cfg.views[self.view_idx],
                    self.bufnr,
                    self.signcolumn
                ))
                self.view_idx = self.view_idx < #self.cfg.views
                    and self.view_idx + 1
                    or 1
            end)
        end
    end

    -- Don't know why whenever wrap is set in the terminal, a weird resize happens.
    -- Because of that, this is needed here.
    vim.defer_fn(function()
        cmd("silent! doautoall VimResized")
    end, 800)
end

---@private
---A callback for the `Terminal`
---
---@param term Terminal
function Lf:__callback(term)
    if self.cfg.tmux then
        utils.tmux(false)
    end

    if
        (self.action == "cd" or self.action == "lcd")
        and uv.fs_stat(self.tmp_lastdir)
    then
        local last_dir = utils.read_file(self.tmp_lastdir)
        if last_dir ~= nil and last_dir ~= uv.cwd() then
            cmd(("%s %s"):format(self.action, fn.fnameescape(last_dir)))
            return
        end
    elseif uv.fs_stat(self.tmp_sel) then
        term:close()
        for fname in io.lines(self.tmp_sel) do
            local stat = uv.fs_stat(fname)
            if type(stat) == "table" then
                local fesc = fn.fnameescape(fname)
                cmd(("%s %s"):format(self.action, fesc))
                local args = table.concat(self.arglist, " ")
                if string.len(args) > 0 then
                  cmd.argadd(args)
                  cmd.argdedupe()
                end
                self:__set_argv()
            end
        end
    end

    -- Reset the action
    vim.defer_fn(function()
        self.action = self.cfg.default_action
    end, 1)
end

---@private
---Set the arglist value
function Lf:__set_argv()
    local args = {}
    for _, arg in ipairs(fn.argv()) do
        if api.nvim_buf_is_loaded(fn.bufnr(arg)) then
            table.insert(args, uv.fs_realpath(arg))
        end
    end
    self.arglist = args
end

return Lf
