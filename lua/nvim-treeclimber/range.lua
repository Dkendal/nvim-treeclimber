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
	return a.from <= b.from and a.to >= b.to
end

-- A (visibly) contains B
---@param a treeclimber.Range
---@param b treeclimber.Range
---@return boolean
function Range.contains(a, b)
	return a.from < b.from and a.to >= b.to
		or a.from <= b.from and a.to > b.to
end

-- A overlaps B
---@param a treeclimber.Range
---@param b treeclimber.Range
---@return boolean
function Range.overlaps(a, b)
	return not (a.to <= b.from or a.from >= b.to)
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

-- Return invocant range converted from TSNode [0,0) to Vim [1,0] indexing.
---@return treeclimber.Range # range using Vim [1,0] indexing
function Range:to_vim()
	return Range.new(self.from:to_vim(), self.to:to_vim_end())
end

-- TODO: Decide whether to keep the optional to_vim argument now that we have to_vim() method.
---@param node TSNode
---@param to_vim boolean? # convert from Treesitter [0,0) to Vim [1,0] indexing.
---@return treeclimber.Range
function Range.from_node(node, to_vim)
	local range = Range.new4(node:range())
	return to_vim and range:to_vim() or range
end

-- TODO: Decide whether to keep the optional to_vim argument now that we have to_vim() method.
---@param snode TSNode
---@param enode TSNode
---@param to_vim boolean? # convert from Treesitter [0,0) to vim [1,0] indexing.
---@return treeclimber.Range
function Range.from_nodes(snode, enode, to_vim)
	local range = Range.new(Pos:new(snode:start()), Pos:new(enode:end_()))
	return to_vim and range:to_vim() or range
end

-- Return either the invocant Range or an adjusted copy whose extents are fully within the current
-- buffer.
-- Rationale: A TSNode representing (eg) a "chunk" for the entire buffer may have an end_() line
-- just *past* the last physical buffer line. This method simply pulls the end of such ranges back
-- to the col just past the end of the last line of the buffer.
---@param self treeclimber.Range # assumed to use unadjusted [0,0) TSNode indexing.
---@return treeclimber.Range
function Range:buf_limited()
	local eline = vim.fn.line('$')
	-- Design Decision: Check col to err on the side of not making a spurious adjustment.
	-- Rationale: In the special case for which this is designed, treesitter always sets col==0.
	if self.to.row >= eline and self.to.col == 0 then
		-- Change to just past end of last line
		local ecol = vim.fn.col({eline, '$'})
		-- Note: returned Range keeps TSNode [0,0) indexing.
		return Range.new(self.from, Pos:new(eline - 1, ecol - 1))
	end
	-- No fixup needed
	return self
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
	-- Convert to treesitter line indexing.
	return Range.new4(sr-1, sc, er-1, ec, backwards)
end

return Range
