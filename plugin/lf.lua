local M = {}

local api = vim.api
local uv = vim.loop

api.nvim_create_user_command(
    "Lf",
    function(tbl)
        require("lf").start(tbl.args)
    end,
    {nargs = "*", complete = "file"}
)

if g.lf_replace_netrw then
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
                    vim.cmd("sil! au! FileExplorer")
                end
            end
        }
    )

    api.nvim_create_autocmd(
        "BufEnter",
        {
            pattern = "*",
            group = group,
            -- I don't know if this is supposed to be once
            -- The file manager only needs to be opened once, but it could be handled differently
            once = true,
            callback = function()
                local path = Path:new(fn.expand("%"))
                if path:is_dir() then
                    local bufnr = fn.bufnr()
                    vim.cmd(("sil! bwipeout %d"):format(bufnr))

                    local timer = uv.new_timer()
                    timer:start(
                        100,
                        0,
                        vim.schedule_wrap(
                            function()
                                timer:stop()
                                timer:close()
                                require("lf").start(path:absolute())
                            end
                        )
                    )
                end
            end
        }
    )
end

return M
