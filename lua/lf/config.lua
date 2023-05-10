local fn = vim.fn
local o = vim.o

---@alias LfGenericBorder {[1]:string,[2]:string,[3]:string,[4]:string,[5]:string,[6]:string,[7]:string,[8]:string}
---@alias LfBorder "'none'"|"'single'"|"'double'"|"'rounded'"|"'solid'"|"'shadow'"|LfGenericBorder

---@class LfViews
---@field relative "'editor'"|"'win'"|"'cursor'"|"'mouse'"
---@field win number For `relative='win'`
---@field anchor "'NW'"|"'NE'"|"'SW'"|"'SE'" Which corner of float to place `(row, col)`
---@field width number
---@field height number
---@field bufpos {row: number, col: number}
---@field row number|float
---@field col number|float
---@field focusable boolean
---@field zindex number
---@field style "'minimal'"
---@field border LfBorder Border kind
---@field title string|{[1]: string, [2]: string}[] Can be a string or an array of tuples
---@field title_pos "'left'"|"'center'"|"'right'"
---@field noautocmd boolean

---@class LfConfig
---@field default_cmd string Default `lf` command
---@field default_action string Default action when `Lf` opens a file
---@field default_actions { [string]: string } Default action keybindings
---@field winblend number Psuedotransparency level
---@field dir "'gwd'"|"''"|nil|string Directory where `lf` starts ('gwd' is git-working-directory, ""/nil is CWD)
---@field direction "'vertical'"|"'horizontal'"|"'tab'"|"'float'" Window type
---@field border LfBorder Border kind
---@field height number Height of the *floating* window
---@field width number Width of the *floating* window
---@field escape_quit boolean Whether escape should be mapped to quit
---@field focus_on_open boolean Whether Lf should open focused on current file
---@field mappings boolean Whether terminal buffer mappings should be set
---@field tmux boolean Whether `tmux` statusline should be changed by this plugin
---@field highlights table<string, table<string, string>> Highlight table passed to `toggleterm`
---@field layout_mapping string Keybinding to rotate through the window layouts
---@field views LfViews[] Table of layouts to be applied to `nvim_win_set_config`
local Config = {}

---@type LfConfig
local opts = {
    default_cmd = "lf",
    default_action = "drop",
    default_actions = {
        ["<C-t>"] = "tabedit",
        ["<C-x>"] = "split",
        ["<C-v>"] = "vsplit",
        ["<C-o>"] = "tab drop",
    },
    winblend = 10,
    dir = "",
    direction = "float",
    border = "double",
    height = 0.80,
    width = 0.85,
    escape_quit = false,
    focus_on_open = true,
    mappings = true,
    tmux = false,
    highlights = {
        Normal = {link = "Normal"},
        FloatBorder = {link = "FloatBorder"},
    },
    -- Layout configurations
    layout_mapping = "<A-u>",
    views = {
        {width = 0.600, height = 0.600},
        {
            width = 1.0 * fn.float2nr(fn.round(0.7 * o.columns)) / o.columns,
            height = 1.0 * fn.float2nr(fn.round(0.7 * o.lines)) / o.lines,
        },
        {width = 0.800, height = 0.800},
        {width = 0.950, height = 0.950},
    },
}

---Validate configuration values
---@param cfg LfConfig existing configuration options
---@return LfConfig
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
        highlights = {cfg.highlights, "t", false},
        -- Layout configurations
        layout_mapping = {cfg.layout_mapping, "s", false},
        views = {cfg.views, "t", false},
    })

    cfg.winblend = tonumber(cfg.winblend) --[[@as number]]
    cfg.height = tonumber(cfg.height) --[[@as number]]
    cfg.width = tonumber(cfg.width) --[[@as number]]
    return cfg
end

---@private
---Initialize the default configuration
local function init()
    local lf = require("lf")
    -- Keep options from the `lf.setup()` call
    Config = vim.tbl_deep_extend("keep", lf.__conf or {}, opts) --[[@as LfConfig]]
    Config = validate(Config)
    lf.__conf = nil
end

init()

---Set a configuration passed as a function argument (not through `setup`)
---@param cfg? LfConfig configuration options
---@return LfConfig
function Config:override(cfg)
    if type(cfg) == "table" then
        self = vim.tbl_deep_extend("keep", cfg or {}, self) --[[@as LfConfig]]
        self = validate(self)
    end
    return self
end

return setmetatable(Config, {
    __index = function(self, key)
        return rawget(self, key)
    end,
    __newindex = function(_self, _key, _val)
    end,
})
