-- TODO: Cleanup set/new/start functions

return {
  setup = function(config)
    return require("lf.action").Lf:new(config)
  end,
}
