local hsl_convert = require('nvim-treeclimber.vivid.hsl.convert')
local hsl_like = require('nvim-treeclimber.vivid.hsl_like')

--
-- HSL Color
--
-- expects to be called as hsl(hue, sat, light) or hsl("#RRGGBB")
--

local type_fns = {
  from_hex = hsl_convert.hex_to_hsl,
  to_hex = hsl_convert.hsl_to_hex,
  name = function() return "hsl()" end
}

local M = function(h_or_hex, s, l)
  return hsl_like(h_or_hex, s, l, type_fns)
end

return M
