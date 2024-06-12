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
  it("grows the selection", function()
    local buf = vim.api.nvim_create_buf(true, false)

    local out = vim.api.nvim_buf_call(buf, function()
      vim.bo.filetype = "lua"

      vim.api.nvim_buf_set_lines(buf, 0, -1, true, {
        "local a = 1",
        "local b = 1",
        "local d = 1",
        "local e = 1",
      })

      vim.api.nvim_feedkeys("gg", "t", true)
      api.select_expand()

      local mode = vim.api.nvim_get_mode().mode
      local selection_text = nil

      if mode == "v" or mode == "V" then
        local a, b, c, d = api.buf.get_selection_range():values()
        selection_text = vim.api.nvim_buf_get_text(buf, a, b, c, d, {})
      end

      return {
        mode = mode,
        selection = api.buf.get_selection_range():to_list(),
        selection_text = selection_text,
      }
    end)

    assert.are.same("v", out.mode)
    assert.are.same({0, 0, 0, 11}, out.selection)
  end)
end)
