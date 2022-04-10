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
local Config = {
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
}

function Config:set(cfg)
  if cfg and type(cfg) ~= "table" then
    self = vim.tbl_deep_extend("force", self, cfg or {})
  end

  return self
end

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
