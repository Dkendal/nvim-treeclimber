rockspec_format = "3.0"
package = "nvim-treeclimber"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/Dkendal/nvim-treeclimber.git",
}
description = {
   summary = "Neovim plugin for treesitter based navigation and selection.",
   detailed = [[
      Neovim plugin for treesitter based navigation and selection.
      Takes inspiration from ParEdit.
   ]],
   homepage = "https://github.com/dkendal/nvim-treeclimber",
   license = "MIT",
}
test_dependencies = {
   "lua == 5.1",
   "busted ~> 2.2.0",
   "typecheck ~> 3.0",
   "luassert ~> 1.9.0",
   "luacov ~> 0.15.0",
   "luacov-multiple ~> 0.6",
}
test = {
   command = "busted",
   flags = {
      "--shuffle",
      "--coverage",
      "--defer-print",
   },
}
build = {
   type = "builtin",
   modules = {
      ["nvim-treeclimber"] = "lua/nvim-treeclimber.lua",
      ["nvim-treeclimber.api"] = "lua/nvim-treeclimber/api.lua",
      ["nvim-treeclimber.debug"] = "lua/nvim-treeclimber/debug.lua",
      ["nvim-treeclimber.enum"] = "lua/nvim-treeclimber/enum.lua",
      ["nvim-treeclimber.hi"] = "lua/nvim-treeclimber/hi.lua",
      ["nvim-treeclimber.logger"] = "lua/nvim-treeclimber/logger.lua",
      ["nvim-treeclimber.math"] = "lua/nvim-treeclimber/math.lua",
      ["nvim-treeclimber.pos"] = "lua/nvim-treeclimber/pos.lua",
      ["nvim-treeclimber.range"] = "lua/nvim-treeclimber/range.lua",
      ["nvim-treeclimber.ring_buffer"] = "lua/nvim-treeclimber/ring_buffer.lua",
      ["nvim-treeclimber.stack"] = "lua/nvim-treeclimber/stack.lua",
      ["nvim-treeclimber.vivid.hsl.convert"] = "lua/nvim-treeclimber/vivid/hsl/convert.lua",
      ["nvim-treeclimber.vivid.hsl.type"] = "lua/nvim-treeclimber/vivid/hsl/type.lua",
      ["nvim-treeclimber.vivid.hsl_like"] = "lua/nvim-treeclimber/vivid/hsl_like.lua",
      ["nvim-treeclimber.vivid.hsluv.convert"] = "lua/nvim-treeclimber/vivid/hsluv/convert.lua",
      ["nvim-treeclimber.vivid.hsluv.lib"] = "lua/nvim-treeclimber/vivid/hsluv/lib.lua",
      ["nvim-treeclimber.vivid.hsluv.type"] = "lua/nvim-treeclimber/vivid/hsluv/type.lua",
      ["nvim-treeclimber.vivid.rgb.convert"] = "lua/nvim-treeclimber/vivid/rgb/convert.lua",
   },
   copy_directories = {},
}
