local Range = require("nvim-treeclimber.range")
local Pos = require("nvim-treeclimber.pos")
local assert = require("luassert")

describe("order_ascending/1", function()
	it("produces a range in order", function()
		local expected = Range.new(Pos.new(0, 0), Pos.new(0, 1))

		assert.is.same(expected, Range.order_ascending(Range.new(Pos.new(0, 0), Pos.new(0, 1))))

		assert.is.same(expected, Range.order_ascending(Range.new(Pos.new(0, 1), Pos.new(0, 0))))
	end)
end)

describe("order_descending/1", function()
	it("produces a range in descending order", function()
		local expected = Range.new(Pos.new(0, 1), Pos.new(0, 0))

		assert.is.same(expected, Range.order_descending(Range.new(Pos.new(0, 0), Pos.new(0, 1))))

		assert.is.same(expected, Range.order_descending(Range.new(Pos.new(0, 1), Pos.new(0, 0))))
	end)
end)
