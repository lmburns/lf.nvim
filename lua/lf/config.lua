--- @class Config
--- @field default_cmd string default `lf` command
--- @field default_action string default action when `Lf` opens a file
--- @field default_actions table default action keybindings
--- @field winblend number psuedotransparency level
--- @field dir string directory where `lf` starts ('gwd' is git-working-directory)
--- @field direction string window type: float horizontal vertical
--- @field border string border kind: single double shadow curved
--- @field height number height of the *floating* window
--- @field width number width of the *floating* window
--- @field mappings boolean whether terminal buffer mappings should be set
local Config = {}

-- A local function that runs each time allows for a global `.setup()` to work

--- Initialize the default configuration
local function init()
  local lf = require("lf")
  vim.validate({ config = { lf._config, "table", true } })

  local opts = {
    default_cmd = "lf",
    default_action = "edit",
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
    mappings = true,
  }

  Config = vim.tbl_deep_extend("keep", lf._config or {}, opts)
  lf._config = nil
end

init()

local notify = require("lf.utils").notify

---Verify that configuration options that are numbers are numbers or can be converted to numbers
---@param field string `Config` field to check
function Config:__check_number(field)
  if type(field) == "string" then
    local res = tonumber(field)
    if res == nil then
      notify(("invalid option for winblend: %s"):format(field))
      return self.winblend
    else
      return res
    end
  end
end

---Set a configuration passed as a function argument (not through `setup`)
---@param cfg table configuration options
---@return Config
function Config:set(cfg)
  if cfg and type(cfg) == "table" then

    cfg.winblend = self:__check_number(cfg.winblend)
    cfg.height = self:__check_number(cfg.height)
    cfg.width = self:__check_number(cfg.width)

    self = vim.tbl_deep_extend("force", self, cfg or {})
  end

  return self
end

---Get the entire configuration if empty, else get the given key
---@param key string option to get
---@return Config
function Config:get(key)
  if key then
    return self[key]
  end
  return self
end

return setmetatable(
    Config, {
      __index = function(this, k)
        return this[k]
      end,
      __newindex = function(this, k, v)
        this[k] = v
      end,
    }
)
