--- @class treeclimber.Pos
--- @field row integer
--- @field col integer
local Pos = {}

--- @param row integer
--- @param col integer
--- @return treeclimber.Pos
function Pos:new(row, col)
	local pos = {
		row = row,
		col = col,
	}

	setmetatable(pos, self)

	self.__index = self

	return pos
end

--- @param list integer[]
--- @return treeclimber.Pos
function Pos.from_list(list)
	return Pos:new(list[1], list[2])
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:__lt(other)
	return Pos.lt(self, other)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:__gt(other)
	return Pos.gt(self, other)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:__eq(other)
	return Pos.eq(self, other)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:__add(other)
	return Pos.add(self, other)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:__sub(other)
	return Pos.sub(self, other)
end

function Pos:__tostring()
	return string.format("(%d, %d)", self.row, self.col)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:__mul(other)
	return Pos:new(self.row * other, self.col * other)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:__div(other)
	return Pos:new(self.row / other, self.col / other)
end

-- Convert 1 indexed row to 0 indexed
-- Vim pos -> Tree-sitter pos
--- @return treeclimber.Pos
function Pos:to_ts()
	return Pos:new(self.row - 1, self.col)
end

-- Convert 0 indexed row to 1 indexed
-- Tree-sitter treeclimber.Pos -> Vim treeclimber.Pos
--- @return treeclimber.Pos
function Pos:to_vim()
	return Pos:new(self.row + 1, self.col)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:gt(other)
	return (self.row > other.row) or (self.row == other.row and self.col > other.col)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:add(other)
	return Pos:new(self.row + other.row, self.col + other.col)
end

--- @param other treeclimber.Pos
--- @return treeclimber.Pos
function Pos:sub(other)
	return Pos:new(self.row - other.row, self.col - other.col)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:eq(other)
	return self.row == other.row and self.col == other.col
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:gte(other)
	return Pos.gt(self, other) or Pos.eq(self, other)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:lt(other)
	return (self.row < other.row) or (self.row == other.row and self.col < other.col)
end

--- @param other treeclimber.Pos
--- @return boolean
function Pos:lte(other)
	return not Pos.gt(self, other)
end

--- @return integer, integer
function Pos:values()
	return self.row, self.col
end

return Pos
