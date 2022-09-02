local utils = require("lf.utils")

local fn = vim.fn
local o = vim.o

---@alias Layout.Relative
---| 'editor' # Global editor grid
---| 'win' # Window given or current window
---| 'cursor' # Cursor position in current window

---@alias Layout.Anchor
---| 'NW' # Northwest
---| 'NE' # Northeast
---| 'SW' # Southwest
---| 'SE' # Southeast

---@alias Layout.Border
---| 'none' # No border
---| 'single' # A single line box
---| 'double' # A double line box
---| 'rounded' # A single line box with rounded corners
---| 'solid' # Adds padding by a single whitespace cell
---| 'shadow' # A drop shadow effect by blending with background

---@class LfLayout
---@field winblend number: psuedotransparency level
---@field relative Layout.Relative
---@field anchor Layout.Anchor
---@field width number Window width
---@field height number Window height
---@field row number Row position in units
---@field col number Column position in units
---@field zindex number Higher `zindex` go on top of floats with lower `zindex`
---@field border Layout.Border Window border

---@class LfConfig
---@field default_cmd string: default `lf` command
---@field default_action string: default action when `Lf` opens a file
---@field default_actions table: default action keybindings
---@field dir string: directory where `lf` starts ('gwd' is git-working-directory, "" is CWD)
---@field escape_quit boolean: whether escape should be mapped to quit
---@field focus_on_open boolean: whether Lf should open focused on current file
---@field mappings boolean: whether terminal buffer mappings should be set
---@field tmux boolean: whether tmux statusline should be changed by this plugin
---@field highlights table: highlight table to pass to `toggleterm`
---@field layout_mapping string: keybinding to rotate through the window layouts
---@field presets LfLayout Table of layouts to be applied to `nvim_win_set_config`
---@field layout LfLayout Initial window options
local opts = {
    default_cmd = "lf",
    default_action = "edit",
    default_actions = {
        ["<C-t>"] = "tabedit",
        ["<C-x>"] = "split",
        ["<C-v>"] = "vsplit",
        ["<C-o>"] = "tab drop"
    },
    dir = "",
    escape_quit = false,
    focus_on_open = true,
    mappings = true,
    tmux = false,
    highlights = {
        -- There is an error indexing the attribute
        NormalFloat = {},
        FloatBorder = {}
    },
    -- Layout configurations
    layout_mapping = "<A-u>",
    presets = {
        {width = 0.600, height = 0.600},
        {},
        {
            width = 1.0 * fn.float2nr(utils.round(0.7 * o.columns)) / o.columns,
            height = 1.0 * fn.float2nr(utils.round(0.7 * o.lines)) / o.lines
        },
        {width = 0.800, height = 0.800},
        {width = 0.950, height = 0.950}
    },
    -- Initial layout
    layout = {
        width = fn.float2nr(utils.round(0.85 * o.columns)),
        height = fn.float2nr(utils.round(0.8 * o.lines)),
        relative = "editor",
        border = "rounded",
        winblend = 10
    }
}

---@type LfConfig
local Config = {}

---Initialize the default configuration
local function init()
    local lf = require("lf")
    vim.validate({Config = {lf._cfg, "t", true}})

    Config = vim.tbl_deep_extend("keep", lf._cfg or {}, opts) --[[@as LfConfig]]
    vim.validate(
        {
            default_cmd = {Config.default_cmd, "s", false},
            default_action = {Config.default_action, "s", false},
            default_actions = {Config.default_actions, "t", false},
            dir = {Config.dir, "s", false},
            escape_quit = {Config.escape_quit, "b", false},
            focus_on_open = {Config.focus_on_open, "b", false},
            mappings = {Config.mappings, "b", false},
            tmux = {Config.tmux, "b", false},
            highlights = {Config.highlights, "t", false},
            -- Layout configurations
            layout_mapping = {Config.layout_mapping, "s", false},
            presets = {Config.presets, "t", false},
            height = {Config.layout.height, {"n", "s"}, false},
            width = {Config.layout.width, {"n", "s"}, false},
            winblend = {Config.layout.winblend, {"n", "s"}, false},
            border = {Config.layout.border, "s", false}
        }
    )

    if Config.layout_mapping == "" then
        Config.layout_mapping = nil
    end

    -- Just run `tonumber` on all items that can be strings
    -- Checking if each one is a string might take longer
    Config.layout.winblend = tonumber(Config.layout.winblend) --[[@as number]]
    Config.layout.height = tonumber(Config.layout.height) --[[@as number]]
    Config.layout.width = tonumber(Config.layout.width) --[[@as number]]

    lf._cfg = nil
end

init()

---Set configuration options after the `.setup()` call has already been made
---@param cfg LfConfig configuration options
---@return LfConfig?
function Config:set(cfg)
    if cfg and type(cfg) == "table" then
        self = vim.tbl_deep_extend("force", self, cfg or {})

        vim.validate(
            {
                default_cmd = {self.default_cmd, "s", false},
                default_action = {self.default_action, "s", false},
                default_actions = {self.default_actions, "t", false},
                dir = {self.dir, "s", false},
                escape_quit = {self.escape_quit, "b", false},
                focus_on_open = {self.focus_on_open, "b", false},
                mappings = {self.mappings, "b", false},
                tmux = {self.tmux, "b", false},
                highlights = {self.highlights, "t", false},
                -- Layout configurations
                layout_mapping = {self.layout_mapping, "s", false},
                presets = {self.presets, "t", false},
                height = {self.layout.height, {"n", "s"}, false},
                width = {self.layout.width, {"n", "s"}, false},
                winblend = {self.layout.winblend, {"n", "s"}, false},
                border = {self.layout.border, "s", false}
            }
        )

        -- Just run `tonumber` on all items that can be strings
        -- Checking if each one is a string might take longer
        self.layout.winblend = tonumber(self.layout.winblend)
        self.layout.height = tonumber(self.layout.height)
        self.layout.width = tonumber(self.layout.width)
    end

    return self
end

---Get the entire configuration if empty, else get the given key
---@param key string? option to get
---@return LfConfig
function Config:get(key)
    if key then
        return self[key]
    end
    return self
end

return setmetatable(
    Config,
    {
        __index = function(self, k)
            return self[k]
        end,
        __newindex = function(self, k, v)
            self[k] = v
        end
    }
)
