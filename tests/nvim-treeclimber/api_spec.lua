local assert = require("luassert")
local api = require("nvim-treeclimber.api")
local Range = require("nvim-treeclimber.range")

local function parse(source)
  ---@type vim.treesitter.LanguageTree
  local lt = vim.treesitter.get_string_parser(source, "lua")
  ---@type TSTree?
  local tree = lt:parse()[1]

  if tree == nil then
    error("Failed to parse")
  end

  return tree
end

describe("named_descendant_for_range/2", function()
  it("returns the node that is covered by the range", function()
    local source = [[local a = 1]]
    local node = parse(source):root()

    local actual = api.named_descendant_for_range(node, Range.new4(0, 10, 0, 11))

    assert(actual)

    assert.are.equal(actual:sexpr(), "")
  end)
end)

describe("expand_node/2", function()
  it("works", function()
    local source = [[local a = 1]]
    local node = parse(source):root()

    local actual = api.expand_node(node, Range.new4(1, 10, 1, 11))

    assert(actual)
    assert.are.equal(actual:byte_length(), 1)
    assert.are.equal(actual:sexpr(), "")
  end)
end)

local a = 1
