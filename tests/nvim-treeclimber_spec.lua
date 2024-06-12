local m = require("nvim-treeclimber")

describe("hello world", function()
	it("should be true", function()
		assert.is_true(true)
	end)
end)

describe("select_expand", function()
	it("works", function()
		local text = [[
			local a = { x = 1, y = 2 }
		]]

		---@type vim.treesitter.LanguageTree
		local tree = vim.treesitter.get_string_parser(text, "lua")
		local root = tree:parse()[1]:root()

	end)
end)
