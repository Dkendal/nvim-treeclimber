local argcheck = require("typecheck").argcheck

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

describe("api.node.named_descendant_for_range/2", function()
  it("returns the node that is covered by the range", function()
    local source = [[local a = 1]]
    local node = parse(source):root()

    local actual = api.node.named_descendant_for_range(node, Range.new4(0, 10, 0, 11))

    assert(actual)

    assert.are.equal(actual:sexpr(), "(number)")
  end)
end)

describe("api.node.grow/2", function()
  it("grows the selection", function()
    local source = [[local a = 1]]
    local root = parse(source):root()

    -- Position of "1"
    local actual = api.node.named_descendant_for_range(root, Range.new4(0, 10, 0, 11))

    assert(actual)

    actual = api.node.grow(actual)

    assert(actual)

    assert.are_same({ 0, 6, 0, 11 }, { actual:range() })

    actual = api.node.grow(actual)
    assert(actual)
    assert.are_same({ 0, 0, 0, 11 }, { actual:range() })

    -- Stops at the root
    actual = api.node.grow(actual)
    assert(actual)
    assert.are_same({ 0, 0, 0, 11 }, { actual:range() })
  end)
end)

describe("api.node.shrink/2", function()
  it("shrinks the selection", function()
    local source = [[local a = 1]]
    local actual = parse(source):root()

    actual = api.node.shrink(actual, api.History.new({}))
    assert(actual)

    assert.are_same({ 0, 6, 0, 11 }, { actual:range() })

    actual = api.node.shrink(actual)
    assert(actual)
    assert.are_same({ 0, 6, 0, 7 }, { actual:range() })

    -- Can't shrink further
    actual = api.node.shrink(actual)
    assert(actual)
    assert.are_same({ 0, 6, 0, 7 }, { actual:range() })
  end)
end)
