local Pos = require("nvim-treeclimber.pos")

---@class treeclimber.Range
---@field from treeclimber.Pos
---@field to treeclimber.Pos
---@field backwards boolean
local Range = {}


---@param to treeclimber.Pos
---@param from treeclimber.Pos
---@param backwards boolean?
---@return treeclimber.Range
function Range.new(from, to, backwards)
	local range = {
		from = from,
		to = to,
		backwards = backwards,
	}

	setmetatable(range, Range)

	return range
end

function Range.__index(_, key)
	return Range[key]
end

---@param row1 integer
---@param col1 integer
---@param row2 integer
---@param col2 integer
---@param backwards boolean?
function Range.new4(row1, col1, row2, col2, backwards)
	return Range.new(Pos:new(row1, col1), Pos:new(row2, col2), backwards)
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

-- TODO: Rethink the order methods in light of backwards range support.
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

-- Accept a range of the following form...
--   nvim_win_get_cursor(0)[1], nvim_win_get_cursor(0)[2], line('v'), col('v')
-- ...and convert to a treeclimber.Range that uses treesitter (0,0) indexing, possibly
-- with the backwards attribute set.
---@param sr integer
---@param sc integer
---@param er integer
---@param ec integer
---@return treeclimber.Range
function Range.from_visual(sr, sc, er, ec)
	local backwards
	if sr > er or (sr == er and sc > ec - 1) then
		-- backwards range: Adjust ranges or set backwards range flag.
		sr, er = er, sr
		sc, ec = ec - 1, sc + 1
		backwards = true
	end
	local r = Range.new4(sr-1, sc, er-1, ec, backwards)
	-- Convert to treesitter line indexing.
	return Range.new4(sr-1, sc, er-1, ec, backwards)
end

return Range
