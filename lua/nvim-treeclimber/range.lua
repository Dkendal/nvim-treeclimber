local Pos = require("nvim-treeclimber.pos")

---@class treeclimber.Range
---@field from treeclimber.Pos
---@field to treeclimber.Pos
local Range = {}

---@param to treeclimber.Pos
---@param from treeclimber.Pos
---@return treeclimber.Range
function Range.new(from, to)
	local range = {
		from = from,
		to = to,
	}

	setmetatable(range, Range)

	return range
end

function Range.__index(_, key)
	return Range[key]
end

function Range.new4(row1, col1, row2, col2)
	return Range.new(Pos:new(row1, col1), Pos:new(row2, col2))
end

---@param a treeclimber.Range
---@param b treeclimber.Range
---@return boolean
function Range.__eq(a, b)
	return Range.eq(a, b)
end

function Range:__tostring()
	return string.format("(%d, %d)", self.from, self.to)
end

---@param a treeclimber.Range
---@param b treeclimber.Range
---@return boolean
function Range.eq(a, b)
	return Pos.eq(a.from, b.from) and Pos.eq(a.to, b.to)
end

-- A covers B
---@param a treeclimber.Range
---@param b treeclimber.Range
---@return boolean
function Range.covers(a, b)
	return Pos.lte(a[1], b[1]) and Pos.gte(a[2], b[2])
end

---@param range treeclimber.Range
---@return treeclimber.Range
function Range.order_ascending(range)
	if range.from > range.to then
		return Range.new(range.to, range.from)
	end

	return range
end

---@param range treeclimber.Range
---@return treeclimber.Range
function Range.order_descending(range)
	if range.from < range.to then
		return Range.new(range.to, range.from)
	end

	return range
end

---@return integer, integer, integer, integer
function Range:values()
	local a, b = self.from:values()
	local c, d = self.to:values()
	return a, b, c, d
end

---@return Range4
function Range:to_list()
	return { self.from.row, self.from.col, self.to.row, self.to.col }
end

---@param range treeclimber.Range
---@return treeclimber.Pos, treeclimber.Pos
function Range.positions(range)
	return range.from, range.to
end

---@param node TSNode
---@return treeclimber.Range
function Range.from_node(node)
	return Range.new4(node:range())
end

return Range
