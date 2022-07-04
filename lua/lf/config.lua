--- @class Config
--- @field default_cmd string: default `lf` command
--- @field default_action string: default action when `Lf` opens a file
--- @field default_actions table: default action keybindings
--- @field winblend number: psuedotransparency level
--- @field dir string: directory where `lf` starts ('gwd' is git-working-directory, "" is CWD)
--- @field direction string: window type: float horizontal vertical
--- @field border string: border kind: single double shadow curved
--- @field height number: height of the *floating* window
--- @field width number: width of the *floating* window
--- @field escape_quit boolean: whether escape should be mapped to quit
--- @field focus_on_open boolean: whether Lf should open focused on current file
--- @field mappings boolean: whether terminal buffer mappings should be set
--- @field tmux boolean: whether tmux statusline should be changed by this plugin
--- @field highlights table: highlight table to pass to `toggleterm`
--- @field layout_mapping string: keybinding to rotate through the window layouts
--- @field views table: table of layouts to be applied to `nvim_win_set_config`
local Config = {}

local fn = vim.fn
local o = vim.o

-- A local function that runs each time allows for a global `.setup()` to work

--- Initialize the default configuration
local function init()
    local lf = require("lf")
    vim.validate({Config = {lf._cfg, "table", true}})

    local opts = {
        default_cmd = "lf",
        default_action = "edit",
        default_actions = {
            ["<C-t>"] = "tabedit",
            ["<C-x>"] = "split",
            ["<C-v>"] = "vsplit",
            ["<C-o>"] = "tab drop"
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
        highlights = {},
        -- Layout configurations
        layout_mapping = "<A-u>",
        views = {
            {width = 0.600, height = 0.600},
            {
                width = 1.0 * fn.float2nr(fn.round(0.7 * o.columns)) / o.columns,
                height = 1.0 * fn.float2nr(fn.round(0.7 * o.lines)) / o.lines
            },
            {width = 0.800, height = 0.800},
            {width = 0.950, height = 0.950}
        }
    }

    Config = vim.tbl_deep_extend("keep", lf._cfg or {}, opts)
    lf._cfg = nil
end

init()

-- local notify = require("lf.utils").notify

---Set a configuration passed as a function argument (not through `setup`)
---@param cfg table configuration options
---@return Config?
function Config:set(cfg)
    if cfg and type(cfg) == "table" then
        self = vim.tbl_deep_extend("force", self, cfg or {})

        vim.validate(
            {
                default_cmd = {self.default_cmd, "s", false},
                default_action = {self.default_action, "s", false},
                default_actions = {self.default_actions, "t", false},
                winblend = {self.winblend, {"n", "s"}, false},
                dir = {self.dir, "s", false},
                direction = {self.direction, "s", false},
                border = {self.border, "s", false},
                height = {self.height, {"n", "s"}, false},
                width = {self.width, {"n", "s"}, false},
                escape_quit = {self.escape_quit, "b", false},
                focus_on_open = {self.focus_on_open, "b", false},
                mappings = {self.mappings, "b", false},
                tmux = {self.tmux, "b", false},
                highlights = {self.highlights, "t", false},
                -- Layout configurations
                layout_mapping = {self.layout_mapping, "s", false},
                views = {self.views, "t", false}
            }
        )

        -- Just run `tonumber` on all items that can be strings
        -- Checking if each one is a string might take longer
        self.winblend = tonumber(self.winblend)
        self.height = tonumber(self.height)
        self.width = tonumber(self.width)
    end

    return self
end

---Get the entire configuration if empty, else get the given key
---@param key string? option to get
---@return Config
function Config:get(key)
    if key then
        return self[key]
    end
    return self
end

return setmetatable(
    Config,
    {
        __index = function(this, k)
            return this[k]
        end,
        __newindex = function(this, k, v)
            this[k] = v
        end
    }
)
