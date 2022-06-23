local M = {}

if _G.loaded_lf == 1 then
    return
end

local api = vim.api
local fn = vim.fn

_G.loaded_lf = 1

api.nvim_create_user_command(
    "Lf",
    function(tbl)
        require("lf").start(tbl.args)
    end,
    {nargs = "*", complete = "file"}
)

if vim.g.lf_netrw == 1 or vim.g.lf_netrw then
    local group = api.nvim_create_augroup("ReplaceNetrwWithLf", {clear = true})

    api.nvim_create_autocmd(
        "VimEnter",
        {
            pattern = "*",
            group = group,
            once = true,
            callback = function()
                if fn.exists("#FileExplorer") then
                    vim.cmd("silent! autocmd! FileExplorer")
                end
            end
        }
    )

    api.nvim_create_autocmd(
        "BufEnter",
        {
            pattern = "*",
            group = group,
            once = true,
            callback = function()
                local bufnr = api.nvim_get_current_buf()
                local path = require("plenary.path"):new(fn.expand("%"))
                if path:is_dir() and fn.argc() ~= 0 then
                    vim.cmd(("sil! bwipeout! %s"):format(bufnr))

                    vim.defer_fn(
                        function()
                            require("lf").start(path:absolute())
                        end,
                        1
                    )
                end
            end
        }
    )
end

return M
