# Nvim-Treeclimber

Neovim plugin for treesitter based navigation and selection.
Takes inspiration from [ParEdit](https://calva.io/paredit/).

Requires neovim >= 0.10.

## Usage

### Navigation

| Plug Mapping | Mode | Action | Demo |
| ------------ | ---- | ------ | ---- |
| `<Plug>(treeclimber-select-previous)` | n,x,o | Select the previous sibling node | ![select-prev](https://user-images.githubusercontent.com/3162299/203088192-5c3a7f49-aa8f-4927-b9f2-1dc9c5245364.gif) |
| `<Plug>(treeclimber-select-shrink)` | n,x,o | Shrink selection (select child node) | ![select-shrink](https://user-images.githubusercontent.com/3162299/203088198-1c326834-bf6f-4782-9750-a04e319d449d.gif) |
| `<Plug>(treeclimber-select-parent)` | n,x,o | Expand selection (select parent node) | ![select-expand](https://user-images.githubusercontent.com/3162299/203088161-c29d3413-4e58-4da4-ae7e-f8ab6b379157.gif) |
| `<Plug>(treeclimber-select-next)` | n,x,o | Select the next sibling node | ![select-next](https://user-images.githubusercontent.com/3162299/203088185-3f0cb56a-a6b0-4f02-b402-c1bd8adbacae.gif) |
| `<Plug>(treeclimber-select-grow-forward)` | n,x,o | Grow selection forward (add next sibling) | ![grow-selection-next](https://user-images.githubusercontent.com/3162299/203088148-4d486a42-4359-436b-b446-f1947bf4ec46.gif) |
| `<Plug>(treeclimber-select-grow-backward)` | n,x,o | Grow selection backward (add previous sibling) | ![grow-selection-prev](https://user-images.githubusercontent.com/3162299/203088157-84a4510e-eb5c-4689-807a-6540c0593098.gif) |
| `<Plug>(treeclimber-select-siblings-backward)` | n,x,o | Select first sibling | ![select-first-sibling](https://user-images.githubusercontent.com/3162299/203088171-94a044e4-a07d-428b-a2be-c62dfc061672.gif) |
| `<Plug>(treeclimber-select-siblings-forward)` | n,x,o | Select last sibling | ![select-last-sibling](https://user-images.githubusercontent.com/3162299/203088178-5c8a2286-1b67-48c6-be6d-16729cb0851c.gif) |
| `<Plug>(treeclimber-select-top-level)` | n,x,o | Select top-level node | ![select-top-level](https://user-images.githubusercontent.com/3162299/203088210-2846ab50-18ff-48d2-aef1-308369cbc395.gif) |
| `<Plug>(treeclimber-select-backward)` | n,x,o | Select and move to node start | |
| `<Plug>(treeclimber-select-forward-end)` | n,x,o | Select and move to node end | |
| `<Plug>(treeclimber-show-control-flow)` | n | Show control flow | |
| `<Plug>(treeclimber-select-current-node)` | x,o | Select current node (inner) | |
| `<Plug>(treeclimber-select-expand)` | x,o | Select parent node (around) | |

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

## Configuration

The plugin can be configured in three ways:

1. **Using `setup()` function:**
```lua
require('nvim-treeclimber').setup({
  highlight = { auto = true }  -- or other highlight options (see below)
})
```

2. **Using lazy.nvim opts:**
```lua
{
  "dkendal/nvim-treeclimber",
  opts = {
    highlight = { auto = true }
  }
}
```

3. **Setting vim.g.treeclimber directly:**
```lua
vim.g.treeclimber = {
  highlight = { auto = true }
}
```

### Configuration Options

#### highlight

Controls the visual highlighting of treesitter nodes during navigation. Can be:

- `{ auto = true }` (default) - Enable automatic highlighting with default blend value (50)
- `false` - Disable all highlighting  
- `true` - Enable highlighting with default blend value (50)
- `number` - Enable highlighting with custom blend value (0-100, where 0 is no blend and 100 is full blend)
- `function` - Custom function for dynamic highlight setup (e.g., colorscheme changes)

**Examples:**

```lua
-- Disable highlighting
require('nvim-treeclimber').setup({
  highlight = false
})

-- Custom blend value (lighter highlighting)
require('nvim-treeclimber').setup({
  highlight = 25
})

-- Dynamic highlight function (adapts to colorscheme changes)
require('nvim-treeclimber').setup({
  highlight = function()
    local hi = require("nvim-treeclimber.hi")
    
    local Normal = hi.get_hl("Normal", { follow = true })
    local normal = hi.HSLUVHighlight:new(Normal)
    
    local Visual = hi.get_hl("Visual", { follow = true })
    local visual = hi.HSLUVHighlight:new(Visual)
    
    local blend_value = 50
    local set_hl = vim.api.nvim_set_hl
    set_hl(0, "TreeClimberSiblingBoundary", { background = visual.bg.mix(normal.bg, blend_value).hex })
    set_hl(0, "TreeClimberSibling", { background = visual.bg.mix(normal.bg, blend_value).hex })
    set_hl(0, "TreeClimberParent", { background = visual.bg.mix(normal.bg, blend_value).hex })
    set_hl(0, "TreeClimberParentStart", { background = visual.bg.mix(normal.bg, blend_value).hex })
  end
})

-- For hardcoded highlights, disable the plugin's highlighting and set your own:
require('nvim-treeclimber').setup({
  highlight = false
})
vim.api.nvim_set_hl(0, "TreeClimberSiblingBoundary", { bg = "#3c3836" })
vim.api.nvim_set_hl(0, "TreeClimberSibling", { bg = "#504945" })
vim.api.nvim_set_hl(0, "TreeClimberParent", { bg = "#665c54" })
vim.api.nvim_set_hl(0, "TreeClimberParentStart", { bg = "#7c6f64" })
```

The plugin automatically creates these highlight groups that blend the Visual highlight with the Normal background color:
- `TreeClimberSiblingBoundary` - Highlights sibling boundaries
- `TreeClimberSibling` - Highlights sibling nodes  
- `TreeClimberParent` - Highlights parent nodes
- `TreeClimberParentStart` - Highlights parent node start

### Lazy.nvim Configuration

If you're using [lazy.nvim](https://github.com/folke/lazy.nvim), you can configure nvim-treeclimber with lazy-loaded key mappings:

```lua
return {
  "dkendal/nvim-treeclimber",
  config = function()
    require('nvim-treeclimber').setup()
  end,
  keys = {
    -- Core navigation
    { "<M-h>", "<Plug>(treeclimber-select-previous)", mode = { "n", "x", "o" }, desc = "Select previous node" },
    { "<M-l>", "<Plug>(treeclimber-select-next)", mode = { "n", "x", "o" }, desc = "Select next node" },
    { "<M-k>", "<Plug>(treeclimber-select-parent)", mode = { "n", "x", "o" }, desc = "Select parent node" },
    { "<M-j>", "<Plug>(treeclimber-select-shrink)", mode = { "n", "x", "o" }, desc = "Select child node" },
    -- Growth selection
    { "<M-H>", "<Plug>(treeclimber-select-grow-backward)", mode = { "n", "x", "o" }, desc = "Grow selection backward" },
    { "<M-L>", "<Plug>(treeclimber-select-grow-forward)", mode = { "n", "x", "o" }, desc = "Grow selection forward" },
    -- Sibling navigation
    { "<M-[>", "<Plug>(treeclimber-select-siblings-backward)", mode = { "n", "x", "o" }, desc = "Select first sibling" },
    { "<M-]>", "<Plug>(treeclimber-select-siblings-forward)", mode = { "n", "x", "o" }, desc = "Select last sibling" },
    -- Top level
    { "<M-g>", "<Plug>(treeclimber-select-top-level)", mode = { "n", "x", "o" }, desc = "Select top-level node" },
    -- Movement selection
    { "<M-b>", "<Plug>(treeclimber-select-backward)", mode = { "n", "x", "o" }, desc = "Select and move to node start" },
    { "<M-e>", "<Plug>(treeclimber-select-forward-end)", mode = { "n", "x", "o" }, desc = "Select and move to node end" },
    -- Visual/operator mode specific
    { "i.", "<Plug>(treeclimber-select-current-node)", mode = { "x", "o" }, desc = "Select current node (inner)" },
    { "a.", "<Plug>(treeclimber-select-expand)", mode = { "x", "o" }, desc = "Select parent node (around)" },
    -- Commands
    { "<leader>k", "<Plug>(treeclimber-show-control-flow)", mode = "n", desc = "Show control flow" },
  },
  cmd = { "TCDiffThis", "TCShowControlFlow", "TCHighlightExternalDefinitions" },
}
```

### Custom Key Bindings

To customize key bindings, use the `<Plug>` mappings from the table above. For example, to use `H/L` for navigation:

```lua
local tc = require('nvim-treeclimber')

-- Use custom keys
vim.keymap.set({ "n", "x", "o" }, "H", "<Plug>(treeclimber-select-previous)")
vim.keymap.set({ "n", "x", "o" }, "L", "<Plug>(treeclimber-select-next)")
```

Or use the `keys` attribute if you're using lazy.nvim.

---

Copyright Dylan Kendal 2025.
