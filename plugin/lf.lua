local M = {}

local api = vim.api
local uv = vim.loop
local debounce = require("lf.debounce")

api.nvim_create_user_command(
    "Lf",
    function(fargs)
        require("lf").start(fargs)
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
            command = [[sil! au! FileExplorer]]
        }
    )

    -- api.nvim_create_autocmd(
    --     "BufEnter",
    --     {
    --         pattern = "*",
    --         group = group,
    --         callback = function()
    --             local path = Path:new(fn.expand("%"))
    --             if path:is_dir() then
    --                 vim.cmd("bdelete!")
    --
    --                 -- local timer = uv.new_timer()
    --                 -- timer:start(
    --                 --     100,
    --                 --     0,
    --                 --     vim.schedule_wrap(
    --                 --         function()
    --                 --             -- p(path:absolute())
    --                 --             require("lf").start(path:absolute())
    --                 --         end
    --                 --     )
    --                 -- )
    --
    --                 vim.defer_fn(
    --                     function()
    --                         p(path:absolute())
    --                         -- require("lf").start(path:absolute())
    --                     end,
    --                     100
    --                 )
    --             end
    --         end
    --     }
    -- )
end

return M
