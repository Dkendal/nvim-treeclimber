local hsluv_convert = require('nvim-treeclimber.vivid.hsluv.convert')
local hsl_like = require('nvim-treeclimber.vivid.hsl_like')

--
-- HSLuv Color
--
-- expects to be called as hsluv(hue, sat, light) or hslulv("#RRGGBB")
--

local type_fns = {
  from_hex = hsluv_convert.hex_to_hsluv,
  to_hex = hsluv_convert.hsluv_to_hex,
  name = function() return "hsluv()" end
}

local M = function(h_or_hex, s, l)
  return hsl_like(h_or_hex, s, l, type_fns)
end

return M
