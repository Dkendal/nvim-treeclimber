local M = {}

---@param a table
---@param b table
---@return boolean
--- Check if b is a subset of a
function M.array_subset(a, b)
	for k, v in pairs(a) do
		if type(k) == "number" then
			if v ~= b[k] then
				return false
			end
		end
	end
	return true
end

---@param a table
---@param b table
---@return boolean
--- Check if two tables are equal by value
function M.tbl_eq(a, b)
	if #a ~= #b then
		return false
	end
	for k, v in pairs(a) do
		if v ~= b[k] then
			return false
		end
	end
end

return M

