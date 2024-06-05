---@class treeclimber.Pos
---@field [1] number
---@field [2] number
local Pos = {}

function Pos.new(row, col)
	local pos = {
		row,
		col,
		row = Pos.row,
		col = Pos.col,
		values = Pos.values,
	}

	setmetatable(pos, Pos)

	return pos
end

function Pos.from_list(list)
	return Pos.new(list[1], list[2])
end

function Pos.__lt(a, b)
	return Pos.lt(a, b)
end

function Pos.__gt(a, b)
	return Pos.gt(a, b)
end

function Pos.__eq(a, b)
	return Pos.eq(a, b)
end

function Pos.__add(a, b)
	return Pos.add(a, b)
end

function Pos.__sub(a, b)
	return Pos.sub(a, b)
end

function Pos.__tostring(v)
	return string.format("(%d, %d)", v[1], v[2])
end

function Pos.__mul(a, b)
	return Pos.new(a[1] * b, a[2] * b)
end

function Pos.__div(a, b)
	return Pos.new(a[1] / b, a[2] / b)
end

---@return number
function Pos:row()
	return self[1]
end

---@return number
function Pos:col()
	return self[2]
end

-- Convert 1 indexed row to 0 indexed
-- Vim pos -> Tree-sitter pos
---@param v treeclimber.Pos
---@return treeclimber.Pos
function Pos.to_ts(v)
	return Pos.new(v[1] - 1, v[2])
end

-- Convert 0 indexed row to 1 indexed
-- Tree-sitter treeclimber.Pos -> Vim treeclimber.Pos
---@param v treeclimber.Pos
---@return treeclimber.Pos
function Pos.to_vim(v)
	return Pos.new(v[1] + 1, v[2])
end

---@param a treeclimber.Pos
---@param b treeclimber.Pos
---@return boolean
function Pos.gt(a, b)
	return (a[1] > b[1]) or (a[1] == b[1] and a[2] > b[2])
end

function Pos.add(a, b)
	return Pos.new(a[1] + b[1], a[2] + b[2])
end

function Pos.sub(a, b)
	return Pos.new(a[1] - b[1], a[2] - b[2])
end

---@param a treeclimber.Pos
---@param b treeclimber.Pos
---@return boolean
function Pos.eq(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

---@param a treeclimber.Pos
---@param b treeclimber.Pos
---@return boolean
function Pos.gte(a, b)
	return Pos.gt(a, b) or Pos.eq(a, b)
end

---@param a treeclimber.Pos
---@param b treeclimber.Pos
---@return boolean
function Pos.lt(a, b)
	return (a[1] < b[1]) or (a[1] == b[1] and a[2] < b[2])
end

---@param a treeclimber.Pos
---@param b treeclimber.Pos
---@return boolean
function Pos.lte(a, b)
	return not Pos.gt(a, b)
end

---@return number, number
function Pos:values()
	return self[1], self[2]
end

return Pos
