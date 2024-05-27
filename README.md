# Nvim-Treeclimber

Neovim plugin for treesitter based navigation and selection.
Takes inspiration from [ParEdit](https://calva.io/paredit/).

Requires neovim >= 0.10.

## Usage

### Navigation

| Key binding   | Action                                                                                                                                                                            | Demo                                                                                                                          |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `alt-h`       | Select the previous sibling node.                                                                                                                                                 | ![select-prev](https://user-images.githubusercontent.com/3162299/203088192-5c3a7f49-aa8f-4927-b9f2-1dc9c5245364.gif)          |
| `alt-j`       | Shrink selection. The video also shows growing the selection first. Shrinking selects a child node from the current node, or will undo the action of a previous expand operation. | ![select-shrink](https://user-images.githubusercontent.com/3162299/203088198-1c326834-bf6f-4782-9750-a04e319d449d.gif)        |
| `alt-k`       | Expand selection by selecting the parent of the current node or node under the cursor.                                                                                            | ![select-expand](https://user-images.githubusercontent.com/3162299/203088161-c29d3413-4e58-4da4-ae7e-f8ab6b379157.gif)        |
| `alt-l`       | Select the next sibling node.                                                                                                                                                     | ![select-next](https://user-images.githubusercontent.com/3162299/203088185-3f0cb56a-a6b0-4f02-b402-c1bd8adbacae.gif)          |
| `alt-shift-l` | Add the next sibling to the selection.                                                                                                                                            | ![grow-selection-next](https://user-images.githubusercontent.com/3162299/203088148-4d486a42-4359-436b-b446-f1947bf4ec46.gif)  |
| `alt-shift-h` | Add the previous sibling to the selection.                                                                                                                                        | ![grow-selection-prev](https://user-images.githubusercontent.com/3162299/203088157-84a4510e-eb5c-4689-807a-6540c0593098.gif)  |
| `alt-[`       | Select the first sibling relative to the current node.                                                                                                                            | ![select-first-sibling](https://user-images.githubusercontent.com/3162299/203088171-94a044e4-a07d-428b-a2be-c62dfc061672.gif) |
| `alt-]`       | Select the last sibling relative to the current node .                                                                                                                            | ![select-last-sibling](https://user-images.githubusercontent.com/3162299/203088178-5c8a2286-1b67-48c6-be6d-16729cb0851c.gif)  |
| `alt-g`       | Select the top level node relative to the cursor or selection.                                                                                                                     | ![select-top-level](https://user-images.githubusercontent.com/3162299/203088210-2846ab50-18ff-48d2-aef1-308369cbc395.gif)     |

### Inspection

| Key binding | Action                                                                      | Demo                                     |
| ----------- | --------------------------------------------------------------------------- | ---------------------------------------- |
| `leader-k`  | Populate the quick fix with all branches required to reach the current node | [:TCShowControlFlow](#tcshowcontrolflow) |

### Commands

#### :TCDiffThis

Diff two visual selections based on their AST difference.
Requires that [difft](https://github.com/Wilfred/difftastic) is available in your path.

To use, make your first selection and call `:TCDiffThis`, then make your second selection and call `:TCDiffThis` again.

[tc-diff-this.webm](https://user-images.githubusercontent.com/3162299/203088217-a827f8fc-ea20-4da7-95fe-884e3d82daa5.webm)

#### :TCShowControlFlow

Populate the quick fix with all branches required to reach the current node.

https://user-images.githubusercontent.com/3162299/203097777-a9a84c2d-8dec-4db8-a4c7-4c9a66ca26fe.mp4

## Installation

Use your preferred package manager, or the built-in package system (`:help packages`).

```sh
mkdir -p ~/.config/nvim/pack/dkendal/opt
cd ~/.config/nvim/pack/dkendal/opt
git clone https://github.com/dkendal/nvim-treeclimber.git
```

```lua
-- ~/.config/nvim/init.lua
vim.cmd.packadd('nvim-treeclimber')

require('nvim-treeclimber').setup()
```

If you want to change the default keybindings, call `require('nvim-treeclimber')` rather than calling setup.
See [configuration](#configuration).

## Configuration

**To use default highlight, keymaps, and commands call `require('nvim-treeclimber').setup()`.**

To manually specify the configuration options, take a look at the contents of `lua/nvim-treeclimber.lua` and import or modify the portions that you need.

For example, if you just want the built in user commands and highlights but you want your own keybindings, you can do the following:

```lua

local tc = require('nvim-treeclimber')

tc.setup_augroups()
tc.setup_user_commands()

-- Copied from setup_keymaps
vim.keymap.set("n", "<leader>k", tc.show_control_flow, {})
vim.keymap.set({ "x", "o" }, "i.", tc.select_current_node, { desc = "select current node" })
vim.keymap.set({ "x", "o" }, "a.", tc.select_expand, { desc = "select parent node" })
...
```

---

Copyright Dylan Kendal 2022.
