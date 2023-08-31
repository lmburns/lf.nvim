local fn = vim.fn
local o = vim.o

local utils = require("lf.utils")

---@class Lf.Container
---@field data Lf.Config
---@field group integer Autocmd id
---@field __loaded boolean
local Config = {
    data = {},
    __loaded = false,
}

---@type Lf.Config
local default = {
    default_cmd = "lf",
    default_action = "drop",
    default_actions = {
        ["<C-t>"] = "tabedit",
        ["<C-x>"] = "split",
        ["<C-v>"] = "vsplit",
        ["<C-o>"] = "tab drop",
        ["<C-e>"] = "edit",
        ["<C-g>"] = "argedit",
    },
    winblend = 10,
    dir = "",
    direction = "float",
    border = "double",
    height = fn.float2nr(fn.round(0.75 * o.lines)),
    width = fn.float2nr(fn.round(0.75 * o.columns)),
    escape_quit = false,
    focus_on_open = true,
    mappings = true,
    tmux = false,
    default_file_manager = false,
    disable_netrw_warning = true,
    highlights = {
        Normal = {link = "Normal"},
        FloatBorder = {link = "FloatBorder"},
    },
    count = nil,
    env = {
        clear = false,
        vars = {}, -- NOTE: this doesn't work for now
    },
    -- Layout configurations
    layout_mapping = "<A-u>",
    views = {
        {width = 0.800, height = 0.800},
        {width = 0.600, height = 0.600},
        {width = 0.950, height = 0.950},
        {width = 0.500, height = 0.500, col = 0, row = 0},
        {width = 0.500, height = 0.500, col = 0, row = 0.5},
        {width = 0.500, height = 0.500, col = 0.5, row = 0},
        {width = 0.500, height = 0.500, col = 0.5, row = 0.5},
    },
}

---Validate configuration values
---@param cfg Lf.Config existing configuration options
---@return Lf.Config
local function validate(cfg)
    vim.validate({
        default_cmd = {cfg.default_cmd, "s", false},
        default_action = {cfg.default_action, "s", false},
        default_actions = {cfg.default_actions, "t", false},
        winblend = {cfg.winblend, {"n", "s"}, false},
        dir = {cfg.dir, "s", false},
        direction = {cfg.direction, "s", false},
        border = {cfg.border, {"s", "t"}, false},
        height = {cfg.height, {"n", "s"}, false},
        width = {cfg.width, {"n", "s"}, false},
        escape_quit = {cfg.escape_quit, "b", false},
        focus_on_open = {cfg.focus_on_open, "b", false},
        mappings = {cfg.mappings, "b", false},
        tmux = {cfg.tmux, "b", false},
        default_file_manager = {cfg.default_file_manager, "b", false},
        disable_netrw_warning = {cfg.disable_netrw_warning, "b", false},
        highlights = {cfg.highlights, "t", false},
        count = {cfg.count, "n", true},
        env = {cfg.env, "t", false},
        env_vars = {cfg.env.vars, "t", false},
        env_clear = {cfg.env.clear, "b", false},
        -- Layout configurations
        layout_mapping = {cfg.layout_mapping, "s", false},
        views = {cfg.views, "t", false},
    })

    cfg.winblend = tonumber(cfg.winblend) --[[@as number]]
    cfg.height = tonumber(cfg.height) --[[@as number]]
    cfg.width = tonumber(cfg.width) --[[@as number]]
    return cfg
end

---Set a configuration passed as a function argument (not through `setup`)
---@param cfg? Lf.Config configuration options
---@return Lf.Config
function Config:override(cfg)
    if type(cfg) == "table" then
        self.data = vim.tbl_deep_extend("force", self.data, cfg) --[[@as Lf.Config]]
        self.data = validate(self.data)
    end
    return self.data
end

---Return the configuration
---@param key? string
---@return Lf.Config
function Config:get(key)
    if key then
        return self.data[key]
    end
    return self.data
end

---Initialize the default configuration
function Config.init()
    if Config.__loaded then
        return
    end

    local lf = require("lf")
    -- Keep options from the `lf.setup()` call
    Config.data = vim.tbl_deep_extend("keep", lf.__conf or {}, default) --[[@as Lf.Config]]
    Config.data = validate(Config.data)
    lf.__conf = nil
    Config.__loaded = true
end

return setmetatable(Config, {
    __index = function(self, key)
        return rawget(self, key)
    end,
    __newindex = function(_self, key, val)
        utils.warn(("do not set invalid config values: %s => %s"):format(key, val))
    end,
})

---@alias Lf.border.generic {[1]:string,[2]:string,[3]:string,[4]:string,[5]:string,[6]:string,[7]:string,[8]:string}
---@alias Lf.border "'none'"|"'single'"|"'double'"|"'rounded'"|"'solid'"|"'shadow'"|Lf.border.generic
---@alias Lf.direction "'vertical'"|"'horizontal'"|"'tab'"|"'float'"
---@alias Lf.directory "'gwd'"|"''"|nil|string

---@class Lf.views
---@field width number
---@field height number
---@field relative? "'editor'"|"'win'"|"'cursor'"|"'mouse'"
---@field win? integer For `relative='win'`
---@field anchor? "'NW'"|"'NE'"|"'SW'"|"'SE'" Which corner of float to place `(row, col)`
---@field bufpos? {row: number, col: number}
---@field row? integer|float
---@field col? integer|float
---@field focusable? boolean
---@field zindex? number
---@field style? "'minimal'"
---@field border? Lf.border Border kind
---@field title? string|{[1]: string, [2]: string}[] Can be a string or an array of tuples
---@field title_pos? "'left'"|"'center'"|"'right'"
---@field noautocmd? boolean

---@class Lf.env
---@field clear boolean Should environment variables be cleared?
---@field vars table<string, string|number> Hash of variables to be set on startup

---@class Lf.Config
---@field default_cmd? string Default `lf` command
---@field default_action? string Default action when `Lf` opens a file
---@field default_actions? table<string, string> Default action keybindings
---@field winblend? number Psuedotransparency level
---@field dir? Lf.directory Directory where `lf` starts ('gwd' is git-working-directory, ""/nil is CWD)
---@field direction? Lf.direction Window layout
---@field border? Lf.border Border kind
---@field width? integer Width of the *floating* window
---@field height? integer Height of the *floating* window
---@field escape_quit? boolean Whether escape should be mapped to quit
---@field focus_on_open? boolean Whether Lf should open focused on current file
---@field mappings? boolean Whether terminal buffer mappings should be set
---@field tmux? boolean Whether `tmux` statusline should be changed by this plugin
---@field default_file_manager? boolean Make lf the default file manager for neovim
---@field disable_netrw_warning? boolean Don't display a message when opening a directory with `default_file_manager` as true
---@field highlights? table<string, table<string, string>> Highlight table passed to `toggleterm`
---@field layout_mapping? string Keybinding to rotate through the window layouts
---@field views? Lf.views[] Table of layouts to be applied to `nvim_win_set_config`
---@field env? Lf.env Environment variables
---@field count? integer A number that triggers that specific terminal
