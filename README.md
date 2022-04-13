## Lf.nvim

This is a neovim plugin for the [`lf`](https://github.com/gokcehan/lf) file manager.
It is very similar to [`lf.vim`](https://github.com/ptzz/lf.vim), except for that this is written in Lua.

**NOTE**: This plugin uses [`toggleterm.nvim`](https://github.com/akinsho/toggleterm.nvim) and [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)

### Setup/Configuration

```lua
-- Defaults
require("lf").setup({
  default_cmd = "lf", -- default `lf` command
  default_action = "edit", -- default action when `Lf` opens a file
  default_actions = { -- default action keybindings
    ["<C-t>"] = "tabedit",
    ["<C-x>"] = "split",
    ["<C-v>"] = "vsplit",
    ["<C-o>"] = "tab drop",
  },

  winblend = 10, -- psuedotransparency level
  dir = "", -- directory where `lf` starts ('gwd' is git-working-directory)
  direction = "float", -- window type: float horizontal vertical
  border = "double", -- border kind: single double shadow curved
  height = 0.80, -- height of the *floating* window
  width = 0.85, -- width of the *floating* window
  mappings = true, -- whether terminal buffer mapping is enabled

  ...
  ...
})

vim.api.nvim_set_keymap("n", "<mapping>", "<cmd>lua require('lf').start()", { noremap = true })
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
        default_cmd = "lf", -- default `lf` command
        default_action = "edit", -- default action when `Lf` opens a file
        default_actions = { -- default action keybindings
          ["<C-t>"] = "tabedit",
          ["<C-x>"] = "split",
          ["<C-v>"] = "vsplit",
          ["<C-o>"] = "tab drop",
        },

        winblend = 10, -- psuedotransparency level
        dir = "", -- directory where `lf` starts ('gwd' is git-working-directory)
        direction = "float", -- window type: float horizontal vertical
        border = "double", -- border kind: single double shadow curved
        height = 0.80, -- height of the *floating* window
        width = 0.85, -- width of the *floating* window
        mappings = true, -- whether terminal buffer mapping is enabled

        -- Layout configurations
        layout_mapping = "<A-u>", -- resize window with this key

        views = { -- window dimensions
          { width = 0.600, height = 0.600 },
          {
            width = 1.0 * fn.float2nr(fn.round(0.7 * o.columns)) / o.columns,
            height = 1.0 * fn.float2nr(fn.round(0.7 * o.lines)) / o.lines,
          },
          { width = 0.800, height = 0.800 },
          { width = 0.950, height = 0.950 },
        },
    })
  end,
  { noremap = true }
)
```

There is a command that does basically the exact same thing `:Lf`. This command takes one optional argument,
which is a directory for `lf` to start in.

### `require("lf").start()`
This function is able to take two arguments. The first is the path (`string`), and the second is configuration
options (`table`). If there is only one argument and it is a `table`, this will be treated as configuration
options and `lf` will open in the current directory. The following are all valid:

```lua
require('lf').start({ border = "rounded" }) -- opens in CWD with rounded borders
require('lf').start(nil, { border = "rounded" }) -- opens in CWD with rounded borders

require('lf').start("~/.config") -- opens in `~/.config` with either `.setup()` or default options
require('lf').start("~/.config", nil) -- opens in `~/.config` with either `.setup()` or default options

require('lf').start(nil, nil) -- opens in CWD with either `.setup()` or default options
require('lf').start() -- opens in CWD with either `.setup()` or default options

require('lf').start("~/.config", { border = "rounded" }) -- opens in `~/.config` with rounded borders
```

### Default Actions
These are various ways to open the wanted file(s). The process works by creating a Neovim mapping to send
`lf` a command to manually open the file. The available commands is anything that can open a file.

### Resizing Window
The configuration option `layout_mapping` is the key-mapping that will cycle through the window `views`.
Once the last view is reached, the cycle is restarted.

### Neovim 0.7.0
If you do not have the nightly version of `nvim`, then the `mappings` field can be set to false.
Otherwise, a notification will be display saying that you are not allowed to use these.

```lua
require("lf").start({ mappings = false })
```

### Replacing Netrw
The only configurable environment variable is `g:lf_replace_netrw`, which can be set to `1` to replace `netrw`

### TODO
- [ ] `:LfToggle` command
- [x] Find a way for `lf` to hijack keybindings
- [x] Cycling through various sizes of the terminal (similar to `rnvimr`)
- [ ] Save previous size when terminal is closed, so it is restored on open
- [ ] Set `tmux` title of ToggleTerm
