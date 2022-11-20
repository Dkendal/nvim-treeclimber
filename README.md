# Nvim-Treeclimber

Neovim plugin for treesitter based navigation and selection.
Takes inspiration from [ParEdit](https://calva.io/paredit/).

## Usage

| Key binding | Action           | Demo                                                |
| ----------- | ---------------- | --------------------------------------------------- |
| `alt-h`     | Select backward  | ![select-backward](./doc/images/select-prev.gif)    |
| `alt-j`     | Shrink selection | ![shrink-selection](./doc/images/select-shrink.gif) |
| `alt-k`     | Expand selection | ![expand-selection](./doc/images/select-expand.gif) |
| `alt-l`     | Select forward   | ![select-forward](./doc/images/select-next.gif)     |

### Commands

**:TCDiffThis**
Diff two visual selections based on their AST difference.
Requires that [difft](https://github.com/Wilfred/difftastic) is available in your path.

To use, make your first selection and call `:TCDiffThis`, then make your second selection and call `:TCDiffThis` again.

![:TCDiffThis video demo](./doc/images/tc-diff-this.mp4)

## Installation

```lua
vim.cmd.packadd('nvim-treeclimber')

require('nvim-treeclimber').setup()
```

If you want to change the default keybindings, call `require('nvim-treeclimber')` rather than calling setup.
See [configuration](#configuration).

## Dependencies

At the moment nvim-treeclimber depends on [Lush](https://github.com/rktjmp/lush.nvim) to provide the default highlight groups that are based on your colorscheme.
This is a temporary dependency and will be removed in the future.

If you want to use this plugin without lush manually configure the plugin, see [configuration](#configuration).

## Configuration

**To use default highlight, keymaps, and commands call `require('nvim-treeclimber').setup()`.**

To manually specify the configuration options edit the below snippet as desired, note that this will change in the future:

```lua
local tc = require('nvim-treeclimber')

-- Highlight groups
-- Change if you don't have Lush installed
local color = require("nvim-treeclimber.hi")
local bg = color.bg_hsluv("Normal")
local fg = color.fg_hsluv("Normal")
local dim = bg.mix(fg, 20)

vim.api.nvim_set_hl(0, "TreeClimberHighlight", { background = dim.hex })

vim.api.nvim_set_hl(0, "TreeClimberSiblingBoundary", { background = color.terminal_color_5.hex })

vim.api.nvim_set_hl(0, "TreeClimberSibling", { background = color.terminal_color_5.mix(bg, 40).hex, bold = true })

vim.api.nvim_set_hl(0, "TreeClimberParent", { background = bg.mix(fg, 2).hex })

vim.api.nvim_set_hl(0, "TreeClimberParentStart", { background = color.terminal_color_4.mix(bg, 10).hex, bold = true })

-- Keymaps
vim.keymap.set("n", "<leader>k", tc.show_control_flow, {})

vim.keymap.set({ "x", "o" }, "i.", tc.select_current_node, { desc = "select current node" })

vim.keymap.set({ "x", "o" }, "vim.api.", tc.select_expand, { desc = "select parent node" })

vim.keymap.set(
  { "n", "x", "o" },
  "<M-e>",
  tc.select_forward_end,
  { desc = "select and move to the end of the node, or the end of the next node" }
)

vim.keymap.set(
  { "n", "x", "o" },
  "<M-b>",
  tc.select_backward,
  { desc = "select and move to the begining of the node, or the beginning of the next node" }
)

vim.keymap.set({ "n", "x", "o" }, "<M-[>", tc.select_siblings_backward, {})

vim.keymap.set({ "n", "x", "o" }, "<M-]>", tc.select_siblings_forward, {})

vim.keymap.set(
  { "n", "x", "o" },
  "<M-g>",
  tc.select_top_level,
  { desc = "select the top level node from the current position" }
)

vim.keymap.set({ "n", "x", "o" }, "<M-h>", tc.select_backward, { desc = "select previous node" })

vim.keymap.set({ "n", "x", "o" }, "<M-j>", tc.select_shrink, { desc = "select child node" })

vim.keymap.set({ "n", "x", "o" }, "<M-k>", tc.select_expand, { desc = "select parent node" })

vim.keymap.set({ "n", "x", "o" }, "<M-l>", tc.select_forward, { desc = "select the next node" })

vim.keymap.set({ "n", "x", "o" }, "<M-L>", tc.select_grow_forward, { desc = "Add the next node to the selection" })

vim.keymap.set({ "n", "x", "o" }, "<M-H>", tc.select_grow_backward, { desc = "Add the next node to the selection" })
```
