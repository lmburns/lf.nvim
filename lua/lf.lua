local M = {}
local loaded = false

local function has_feature(cfg)
  if not vim.keymap or not vim.keymap.set then
    local function print_err()
      require("lf.utils").notify(
          "lf.nvim mappings require Neovim 0.7.0 or higher", "error"
      )
    end

    print_err()
    cfg.mappings = false
    -- Lf["__on_open"] = print_err
  end
end

function M.setup(cfg)
  if loaded then
    return
  end

  has_feature(cfg)
  M._cfg = cfg or {}
  loaded = true
end

---Start the file manager
---`nil` can be used as the first parameter to change options and open in CWD
---
---@param path string optional path to start in
function M.start(path, cfg)
  require("lf.main").Lf:new(cfg or M._cfg):start(path)
end

return M
