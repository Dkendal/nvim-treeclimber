require("luacov")

local original_print = print

local busted = require("busted")
local handler = require("busted.outputHandlers.base")()

local buffer = {}

handler.testEnd = function(element, parent, status, trace)
	for _, v in ipairs(buffer) do
		original_print(
			element.trace.short_src
			.. ":"
			.. element.trace.linedefined
			.. "\n↳ ",
			unpack(v)
		)
	end
	buffer = {}
end

busted.subscribe({ "test", "end" }, handler.testEnd)

print = function(...)
	table.insert(buffer, { ... })
end
