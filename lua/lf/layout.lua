local M = {}

local utils = require("lf.utils")
local config = require("lf.config")

local fn = vim.fn
local o = vim.o

local index
local layout
local presets

local function init()
    index = 0
    layout = config.layout
end

init()

return M
