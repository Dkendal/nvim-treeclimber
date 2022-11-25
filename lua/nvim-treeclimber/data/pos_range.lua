local M = {}

local pos = require("nvim-treeclimber.data.pos")

---@class range
---@field [1] pos
---@field [2] pos

---@param a range
---@param b range
---@return boolean
function M.eq(a, b)
	return pos.eq(a[1], b[1]) and pos.eq(a[2], b[2])
end

-- A covers B
---@param a range
---@param b range
---@return boolean
function M.covers(a, b)
	return pos.lte(a[1], b[1]) and pos.gte(a[2], b[2])
end

return M
