--- @generic T
local Stack = {}

---@param self `T`[]
---@param item `T` # The item to push onto the stack
function Stack:push(item)
	table.insert(self, item)
end

---@param self `T`[]
---@return `T` # The item popped from the stack
function Stack:pop()
	return table.remove(self)
end

---@param self `T`[]
---@return `T` # The item popped from the stack
function Stack:peek()
	return self[#self]
end

return Stack
