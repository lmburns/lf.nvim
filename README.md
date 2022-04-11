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
The goal is to allow for these keybindings to be hijacked by `Lf` and make them execute the command
as soon as the keybinding is pressed; however, I am unsure of a way to do this at the moment. If `lf` had a more
programmable API that was similar to `ranger`'s, then something like [`rnvimr`](https://github.com/kevinhwang91/rnvimr)
would be possible, which allows this.

For the moment, these bindings are hijacked on the startup of `Lf`, and when they are pressed, a notification is sent
that your default action has changed. When you go to open a file as you normally would, this command is ran instead
of your `default_action`.

### Resizing Window
The configuration option `layout_mapping` is the keymapping that will cycle through the window `views`.
The way it is setup now seems to work by resizing the window; however, the file manager is not center focused on each resize.
If `lf` is used (i.e., `j` or `k`, etc. is pressed to move around) before the resize, the file manager seems to stay focused,
until the last view is reached and the cycle starts back over. Once the cycle restarts the file manager is not center
focused anymore.

If anyone can get this to work, I would very much appreciate it.

### Neovim 0.7.0
If you do not have the nightly version of `nvim`, then the `mappings` field can be set to false.
Otherwise, a notification will be display saying that you are not allowed to use these.

```lua
require("lf").start({ mappings = false })
```

### Replacing Netrw
The only configurable environment variable is `g:lf_replace_netrw`, which can be set to `1` to replace `netrw`

### TODO
- `:LfToggle` command
- Find a way for `lf` to hijack keybindings
  - This may have to be done by writing to the user's configuration file
  - It would involve mapping each `default_actions` key to the `open` command, which closes the file manager
  - Once the file manager was closed, these would need to be removed
- Allow keybindings to cycle through various sizes of the terminal (similar to `rnvimr`) (**partially done**)
