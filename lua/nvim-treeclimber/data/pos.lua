local M = {}

---@class pos
---@field [1] number
---@field [2] number

-- Convert 1 indexed row to 0 indexed
-- Vim pos -> Tree-sitter pos
---@param v pos
---@return pos
function M.to_ts(v)
	return { v[1] - 1, v[2] }
end

-- Convert 0 indexed row to 1 indexed
-- Tree-sitter pos -> Vim pos
---@param v pos
---@return pos
function M.to_vim(v)
	return { v[1] + 1, v[2] }
end

---@param a pos
---@param b pos
---@return boolean
function M.gt(a, b)
	if a[1] == b[1] then
		return a[2] > b[2]
	end
	return a[1] > b[1]
end

---@param a pos
---@param b pos
---@return boolean
function M.eq(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

---@param a pos
---@param b pos
---@return boolean
function M.gte(a, b)
	return M.gt(a, b) or M.eq(a, b)
end

---@param a pos
---@param b pos
---@return boolean
function M.lt(a, b)
	return not M.gt(b, a) and not M.eq(b, a)
end

---@param a pos
---@param b pos
---@return boolean
function M.lte(a, b)
	return not M.gt(a, b)
end


return M
