# Nvim-Treeclimber

Neovim plugin for treesitter based navigation and selection.
Takes inspiration from [ParEdit](https://calva.io/paredit/).

Requires neovim >= 0.10.

## Usage

### Navigation

The following table lists the treeclimber navigation commands, along with their default keybindings.
See [Configuration](#configuration) for details on changing the defaults.

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

User your preferred package manager, or the built-in package system (`:help packages`).

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "dkendal/nvim-treeclimber",
  opts = {
    -- Provide your desired configuration here, or leave empty to use defaults.
    -- See Configuration section for details...
  },
}
```

### Manual installation

#### Installation via Bash command-line

```sh
mkdir -p ~/.config/nvim/pack/dkendal/opt
cd ~/.config/nvim/pack/dkendal/opt
git clone https://github.com/dkendal/nvim-treeclimber.git
```

#### Loading via Neovim package system

```lua
-- ~/.config/nvim/init.lua
vim.cmd.packadd('nvim-treeclimber')
require('nvim-treeclimber').setup({ --[[ your config here ]] })
```

**Note:** If you call the `setup()` function without arguments, treeclimber uses the defaults documented in the following section.

## Configuration

To override specific elements of the default configuration, provide a sparse option table containing only the keys you wish to change.
The default option table is provided below, with comments documenting the meanings of the various keys.
Any table you provide to `setup()` will be merged into this one, with preference given to your override.
If your override has an invalid format, treeclimber will generally emit a warning and fall back to the default setting.

### Default Option Table

```lua
{
  ui = {
    -- ** Keymaps **
    -- Each entry of the 'keys' table configures the keymap for a single treeclimber function.
    -- Note: The `keys` key itself can be set to a boolean to enable defaults or disable keymaps
    -- altogether.
    ---@alias modestr "n"|"v"|"x"|"o"|"s"|"i"|"!"|""
    ---@alias lhs string                # Used as <lhs> in call to `vim.keymap.set`
    ---@alias KeymapSingle
    ---| [(modestr|modestr[]), lhs]     # override the default <lhs> and/or modes
    ---@alias KeymapEntry
    ---| boolean                        # true to accept default, false to disable
    ---| nil                            # accept default (same as omitting the command name from table)
    ---| lhs                            # override the default <lhs> in default mode(s)
    ---| KeymapSingle                   # override the default <lhs> and/or modes
    ---| KeymapSingle[]                 # idem, but allows multiple, mode-specific <lhs>'s
    ---@type table<string, KeymapEntry>
    keys = {
      show_control_flow = { "n", "<leader>k"},
      select_current_node = {
          {"n", "<M-k>"},
          {{ "x", "o" }, "i."}
      },
      select_first_sibling = {{ "n", "x", "o" }, "<M-[>"},
      select_last_sibling = {{ "n", "x", "o" }, "<M-]>"},
      select_top_level = {{ "n", "x", "o" }, "<M-g>"},
      select_forward = {{ "n", "x", "o" }, "<M-l>"},
      select_backward = {{ "n", "x", "o" }, "<M-h>"},
      select_forward_end = {{ "n", "x", "o" }, "<M-e>"},
      select_grow_forward = {{ "n", "x", "o" }, "<M-L>"},
      select_grow_backward = {{ "n", "x", "o" }, "<M-H>"},
      select_expand = {
        {{"x", "o"}, "a."},
        {{"x", "o"}, "<M-k>"}
      },
      select_shrink = {{ "n", "x", "o" }, "<M-j>"},
    },

    -- ** User commands **
    -- Each entry of the 'cmds table configures the user command for a single treeclimber function.
    -- Note: The 'cmds' key itself can be set to a boolean to enable the defaults or disable user
    -- commands altogether.
    ---@alias UserCommandEntry
    ---| string  # desired name of the user command for this function
    ---| boolean # true to create the command with the default name, false to disable
    ---@type {[string]: UserCommandEntry}|boolean
    cmds = {
      diff_this = "TCDiffThis",
      highlight_external_definitions = "TCHighlightExternalDefinitions",
      show_control_flow = "TCShowControlFlow",
    },
  },

  -- ** Display **
  display = {
    regions = {
      -- Each entry in the table below defines the highlighting applied to one of several regions
      -- relative to the current selection and its siblings/parent. To override the highlighting
      -- for a specific region, set the corresponding key to either a `vim.api.keyset.highlight` or
      -- a callback function that returns one. The callback will be invoked upon colorscheme load
      -- with an `HSLUVHighlights` object that may be used to "mix" new colors from the currently
      -- active normal and visual mode fg/bg colors.
      -- Important Note: The `HSLUV` class provides many color-manipulation methods in addition to
      -- the `mix()` method used in the defaults. The class's type annotation is provided in the
      -- next section. Additional detail may be found in "vivid/hsl_like.lua" in the treeclimber
      -- source.
      -- Note: The `vim.api.keyset.highlight` can be used to specify more than just fg/bg colors:
      -- e.g., the following override would make the currently selected region bold and its siblings
      -- italic:
      --   highlights = {
      --     Selection = {bold = true},
      --     Sibling = {italic = true)
      --   }
      -- Note: You can also disable unwanted regions by setting the corresponding key(s) `false`.
      -- E.g., to disable all but the primary selection region (Selection)...
      --   highlights = {
      --     SiblingStart = false, Sibling = false, Parent = false, ParentStart = false
      --   }
      ---@alias HSLUVHighlight {bg: HSLUV?, fg: HSLUV?, ctermbg: HSLUV?, ctermfg: HSLUV?}
      ---@alias HSLUVHighlights {normal: HSLUVHighlight, visual: HSLUVHighlight}
      ---@alias HighlightCallback fun(o: HSLUVHighlights) : vim.api.keyset.highlight
      ---@alias HighlightEntry
      ---| vim.api.keyset.highlight   # passed to `nvim_set_hl()`
      ---| HighlightCallback          # must return a `vim.api.keyset.highlight`
      ---| boolean                    # true for default highlighting, false to disable the group
      ---| nil                        # default highlighting
      ---@type table<string, HighlightEntry>
      highlights = {
        Selection = function(o) return { bold = true, bg = o.visual.bg.hex } end,
        SiblingStart = false,
        Sibling = function(o) return { bg = o.visual.bg.mix(o.normal.bg, 50).hex } end,
        -- Make Parent bg color noticeably lighter than Siblings.
        Parent = function(o) return { bg = o.visual.bg.mix(o.normal.bg, 80).hex } end,
        ParentStart = false,
      },
      -- `true` to cause attributes like bold and italic to "bleed through" from Parent
      -- to Siblings.
      inherit_attrs = true,
      -- `true` to replace default 'highlights' with user overrides, false or nil to merge
      replace_defaults = false,
    },
  },
}
```

### HSLUV Color Support

As mentioned in the default option comments, an object of type `HSLUV` is made available to the `highlights` option callback functions.
This object facilitates working with *HSL* colors in the more human-friendly *HSLUV* color space.
Its methods and fields are shown here. For further details, look in the treeclimber source (vivid/hsl_like.lua).

```lua
---@class HSLUV
---@field hex string
---@field h number
---@field s number
---@field l number
---@field rotate fun(n: number): HSLUV
---@field ro fun(n: number): HSLUV
---@field saturate fun(n: number): HSLUV
---@field sa fun(n: number): HSLUV
---@field abs_saturate fun(n: number): HSLUV
---@field abs_sa fun(n: number): HSLUV
---@field desaturate fun(n: number): HSLUV
---@field de fun(n: number): HSLUV
---@field abs_desaturate fun(n: number): HSLUV
---@field abs_de fun(n: number): HSLUV
---@field lighten fun(n: number): HSLUV
---@field li fun(n: number): HSLUV
---@field abs_lighten fun(n: number): HSLUV
---@field abs_li fun(n: number): HSLUV
---@field darken fun(n: number): HSLUV
---@field da fun(n: number): HSLUV
---@field abs_darken fun(n: number): HSLUV
---@field abs_da fun(n: number): HSLUV
---@field mix fun(color: HSLUV, n: number): HSLUV
---@field readable fun(): HSLUV
---@field hue fun(n: number): HSLUV
---@field saturation fun(n: number): HSLUV
---@field lightness fun(n: number): HSLUV
```

---

Copyright Dylan Kendal 2022.
