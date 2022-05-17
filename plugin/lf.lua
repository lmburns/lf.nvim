local M = {}

if _G.loaded_lf == 1 then
    return
end

local api = vim.api
_G.loaded_lf = 1

api.nvim_create_user_command(
    "Lfnvim",
    function(tbl)
        require("lf").start(tbl.args)
    end,
    {nargs = "*", complete = "file"}
)

if g.lf_netrw == 1 then
    local Path = require("plenary.path")
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
                local path = Path:new(fn.expand("%"))
                if path:is_dir() and fn.argc() ~= 0 then
                    local bufnr = fn.bufnr()
                    vim.cmd(("sil! bwipeout %d"):format(bufnr))

                    vim.defer_fn(
                        function()
                            require("lf").start(path:absolute())
                        end,
                        100
                    )

                -- This is identical to the function above
                -- local timer = uv.new_timer()
                -- timer:start(
                --     100,
                --     0,
                --     vim.schedule_wrap(
                --         function()
                --             -- timer:stop()
                --             timer:close()
                --             require("lf").start(path:absolute())
                --         end
                --     )
                -- )
                end
            end
        }
    )
end

return M
