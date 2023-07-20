## Lf.nvim

This is a neovim plugin for the [`lf`](https://github.com/gokcehan/lf) file manager.
It is very similar to [`lf.vim`](https://github.com/ptzz/lf.vim), except for that this is written in Lua.

**NOTE**: This plugin uses [`toggleterm.nvim`](https://github.com/akinsho/toggleterm.nvim).

### Installation
```lua
-- Sample configuration is supplied
use({
    "lmburns/lf.nvim",
    config = function()
        -- This feature will not work if the plugin is lazy-loaded
        vim.g.lf_netrw = 1

        require("lf").setup({
            escape_quit = false,
            border = "rounded",
        })

        vim.keymap.set("n", "<M-o>", "<Cmd>Lf<CR>")

        vim.api.nvim_create_autocmd({
            event = "User",
            pattern = "LfTermEnter",
            callback = function(a)
                vim.api.nvim_buf_set_keymap(a.buf, "t", "q", "q", {nowait = true})
            end,
        })
    end,
    requires = {"toggleterm.nvim"}
})
```

### Setup/Configuration

```lua
local fn = vim.fn

-- Defaults
require("lf").setup({
  default_action = "drop", -- default action when `Lf` opens a file
  default_actions = { -- default action keybindings
    ["<C-t>"] = "tabedit",
    ["<C-x>"] = "split",
    ["<C-v>"] = "vsplit",
    ["<C-o>"] = "tab drop",
  },

  winblend = 10, -- psuedotransparency level
  dir = "", -- directory where `lf` starts ('gwd' is git-working-directory, ""/nil is CWD)
  direction = "float", -- window type: float horizontal vertical
  border = "rounded", -- border kind: single double shadow curved
  height = fn.float2nr(fn.round(0.75 * o.lines)), -- height of the *floating* window
  width = fn.float2nr(fn.round(0.75 * o.columns)), -- width of the *floating* window
  escape_quit = true, -- map escape to the quit command (so it doesn't go into a meta normal mode)
  focus_on_open = true, -- focus the current file when opening Lf (experimental)
  mappings = true, -- whether terminal buffer mapping is enabled
  tmux = false, -- tmux statusline can be disabled on opening of Lf
  highlights = { -- highlights passed to toggleterm
    Normal = {link = "Normal"},
    NormalFloat = {link = 'Normal'},
    FloatBorder = {guifg = "<VALUE>", guibg = "<VALUE>"},
  },

  -- Layout configurations
  layout_mapping = "<M-u>", -- resize window with this key
  views = { -- window dimensions to rotate through
    {width = 0.800, height = 0.800},
    {width = 0.600, height = 0.600},
    {width = 0.950, height = 0.950},
    {width = 0.500, height = 0.500, col = 0, row = 0},
    {width = 0.500, height = 0.500, col = 0, row = 0.5},
    {width = 0.500, height = 0.500, col = 0.5, row = 0},
    {width = 0.500, height = 0.500, col = 0.5, row = 0.5},
})

-- Equivalent
vim.keymap.set("n", "<M-o>", "<Cmd>lua require('lf').start()<CR>", {noremap = true})
vim.keymap.set("n", "<M-o>", "<Cmd>Lf<CR>", {noremap = true})
```

Another option is to use `vim.keymap.set`, which requires `nvim` 0.7.0 or higher. This doesn't require local
variables and would allow customization of the program.

```lua
vim.keymap.set(
  "n",
  "<mapping>",
  function()
    require("lf").start(
      -- nil, -- this is the path to open Lf (nil means CWD)
              -- this argument is optional see `.start` below
      {
        -- Pass options (if any) that you would like
        dir = "", -- directory where `lf` starts ('gwd' is git-working-directory)
        direction = "float", -- window type: float horizontal vertical
        border = "double", -- border kind: single double shadow curved
        height = 0.80, -- height of the *floating* window
        width = 0.85, -- width of the *floating* window
        mappings = true, -- whether terminal buffer mapping is enabled
    })
  end,
  {noremap = true}
)
```

There is a command that does basically the exact same thing `:Lf`. This command takes one optional argument,
which is a directory for `lf` to start in.

### `require("lf").start()`
This function is able to take two arguments. The first is the path (`string`), and the second is configuration
options (`table`). If there is only one argument and it is a `table`, this will be treated as configuration
options and `lf` will open in the current directory. The following are all valid:

```lua
require('lf').start({border = "rounded"}) -- opens in CWD with rounded borders
require('lf').start(nil, {border = "rounded"}) -- opens in CWD with rounded borders

require('lf').start("~/.config") -- opens in `~/.config` with either `.setup()` or default options
require('lf').start("~/.config", nil) -- opens in `~/.config` with either `.setup()` or default options

require('lf').start(nil, nil) -- opens in CWD with either `.setup()` or default options
require('lf').start() -- opens in CWD with either `.setup()` or default options

require('lf').start("~/.config", {border = "rounded"}) -- opens in `~/.config` with rounded borders
```

### Highlight Groups
The highlight groups that I know for sure work are the ones mentioned above (`Normal`, `NormalFloat`, `FloatBorder`). These are passed to `toggleterm`, and there is a plan in the future to make these `Lf`'s own groups. For now, a one-shot way to change the color of the border of the terminal is the following:

```vim
:lua require("lf").start({highlights = {FloatBorder = {guifg = "#819C3B"}}})
```

### Default Actions
These are various ways to open the wanted file(s). The process works by creating a Neovim mapping to send
`lf` a command to manually open the file. The available commands are anything that can open a file in Vim.
See `tabpage.txt` and `windows.txt`

### Resizing Window
The configuration option `layout_mapping` is the key-mapping that will cycle through the window `views`.
Once the last view is reached, the cycle is restarted.

### Neovim 0.7.0
If you do not have the nightly version of `nvim`, then the `mappings` field can be set to false.
Otherwise, a notification will be displayed saying that you are not allowed to use them.

```lua
require("lf").start({mappings = false})
```

### Replacing Netrw
The only configurable environment variable is `g:lf_netrw`, which can be set to `1` or `true` to replace `netrw`.
Also, note that this option will not work if `lf` is lazy-loaded.

### Key mappings
The mappings that are listed in the `setup` call above are the default bindings.

* `<C-t>` = `tabedit`
* `<C-x>` = `split`
* `<C-v>` = `vsplit`
* `<C-o>` = `tab drop` (`<r-o>` is also suggested)
* `<M-u>` = resize the floating window

### Notes
The `autocmd` `LfTermEnter` is fired when the terminal buffer first opens

### TODO
- [ ] Set custom filetype
- [ ] `:LfToggle` command
- [ ] Save previous size when terminal is closed, so it is restored on open
- [ ] Set Lualine to `Lf` title
- [ ] Fix weird wrapping error that occurs every so often when moving down a list of files
