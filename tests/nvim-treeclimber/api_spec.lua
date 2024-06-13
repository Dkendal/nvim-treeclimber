local t = require("nvim-treeclimber.test_support")
local assert = require("luassert")
local api = require("nvim-treeclimber.api")
local Range = require("nvim-treeclimber.range")
local get_node_text = vim.treesitter.get_node_text

describe("api.node.named_descendant_for_range/2", function()
  it("returns the node that is covered by the range", function()
    local source = [[local a = 1]]
    local node = t:parse(source):root()

    local actual = api.node.named_descendant_for_range(node, Range.new4(0, 10, 0, 11))

    assert(actual)

    assert.are.equal(actual:sexpr(), "(number)")
  end)
end)

describe("properties", function()
  it("growing and then shrinking should return to the same node", function()
    ---@type string, Range4, TSNode?
    local source, _range, node = t:buf([[
      return a or b or c
                       ^
    ]])

    assert(node)
    local history = { { node:range() } }
    assert.are_same(get_node_text(node, source), "c")

    node = api.node.grow(node)
    assert(node)
    table.insert(history, { node:range() })
    assert.are_same(get_node_text(node, source), "a or b or c")

    node = api.node.grow(node)
    assert(node)
    table.insert(history, { node:range() })
    assert.are_same(get_node_text(node, source), "return a or b or c")

    node = api.node.shrink(node, history)
    assert(node)
    assert.are_same(get_node_text(node, source), "a or b or c")

    node = api.node.shrink(node, history)
    assert(node)
    assert.are_same(get_node_text(node, source), "c")
  end)
end)

describe("api.node.grow/2", function()
  it("grows the selection", function()
    ---@type string, Range4, TSNode?
    local source, _range, node = t:buf([[
      local a = 1
                ^
    ]])

    assert(node)
    node = api.node.grow(node)

    assert(node)
    assert.are_same(get_node_text(node, source), "a = 1")

    node = api.node.grow(node)
    assert(node)
    assert.are_same(get_node_text(node, source), "local a = 1")

    -- Stops at the root
    node = api.node.grow(node)
    assert(node)
    assert.are_same(get_node_text(node, source), "local a = 1")
  end)
end)

describe("api.node.shrink/2", function()
  it("shrinks the selection", function()
    local source, _range, node = t:buf([[
      local a = 1
    ]])

    node = api.node.shrink(node, {})
    assert.are_same(get_node_text(node, source), "a = 1")

    node = api.node.shrink(node, {})
    assert.are_same(get_node_text(node, source), "a")

    -- Can't shrink further
    node = api.node.shrink(node, {})
    assert.are_same(get_node_text(node, source), "a")
  end)
end)

describe("functional tests", function()
  after_each(function()
    vim.cmd([[silent %bwipeout!]])
  end)

  it("growing the selection only selects the current node if starting in normal mode", function()
    local out = t:with_buffer({
      mode = "v",
      text = [[
        local a = 1
                  ^
      ]],
      callback = function()
        api.select_expand()
      end,
    })

    assert.are.same("v", out.mode)
    assert.are.same({ "a = 1" }, out:selected_text())
  end)

  it("selection grows if already in visual mode", function()
    local out = t:with_buffer({
      mode = "v",
      text = [[
        local a = 1
                  ^
      ]],
      callback = function()
        api.select_expand()
      end,
    })

    assert.are.same("v", out.mode)
    assert.are.same({ "a = 1" }, out:selected_text())
  end)
end)
