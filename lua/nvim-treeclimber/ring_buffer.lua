--- Ring Buffer with a single cursor for both writer and reader.
local M = {}

--- Create a new RingBuffer
--- @generic T
--- @param size number
function M.new(size)
	local t = {
		-- The index of the current element
		index = 1,
		-- The elements in the ring
		--- @type table<number, `T`>
		elements = {},
	}

	local function inc()
		t.index = t.index % size + 1
		return t.index
	end

	--- Put an element into the ring
	--- @param value `T`; the element to put
	--- @return number; the index of the element
	function t:put(value)
		self.elements[self.index] = value
		inc()
		return self.index
	end

	--- Get the current element
	--- @return `T`, number; the element and its index
	function t:peek()
		return self.elements[self.index], self.index
	end

	--- Get the current element and move the cursor forward
	--- @return `T`, number; the element and its index
	function t:get()
		local v = t:peek()
		inc()
		return v, self.index
	end

	return t
end

return M
