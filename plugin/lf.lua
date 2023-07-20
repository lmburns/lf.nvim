if vim.g.loaded_lf == 1 then
    return
end

vim.g.loaded_lf = 1

local M = {}

local uv = vim.loop
local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

api.nvim_create_user_command("Lf", function(tbl)
    ---@diagnostic disable-next-line: missing-parameter
    require("lf").start(tbl.args)
end, {nargs = "*", complete = "file"})

if vim.g.lf_netrw == 1 or vim.g.lf_netrw then
    local group = api.nvim_create_augroup("ReplaceNetrwWithLf", {clear = true})

    api.nvim_create_autocmd("VimEnter", {
        pattern = "*",
        group = group,
        once = true,
        callback = function()
            if fn.exists("#FileExplorer") then
                cmd("sil! au! FileExplorer")
            end
        end,
    })

    api.nvim_create_autocmd("BufEnter", {
        pattern = "*",
        group = group,
        once = true,
        callback = function()
            local bufnr = api.nvim_get_current_buf()
            local fname = fn.expand("%:p")
            local stat = uv.fs_stat(fname)
            if type(stat) == "table" then
                if stat.type == "directory" and fn.argc() ~= 0 then
                    cmd(("sil! bwipeout! %s"):format(bufnr))

                    vim.defer_fn(function()
                        require("lf").start(fname)
                    end, 1)
                end
            end
        end,
    })
end

return M
