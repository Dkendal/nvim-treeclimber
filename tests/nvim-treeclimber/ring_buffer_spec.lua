local RingBuffer = require("nvim-treeclimber.ring_buffer")

describe("RingBuffer", function()
	it("works", function()
		local t = RingBuffer.new(3)

		assert.are.same(2, t:put('a'))

		assert.are.same(3, t:put('b'))

		assert.are.same(1, t:put('c'))

		assert.are.same(2, t:put('d'))

		assert.are.same({'b', 3}, {t:get()})

		assert.are.same({'c', 1}, {t:get()})

		assert.are.same({'d', 2}, {t:get()})
	end)
end)
