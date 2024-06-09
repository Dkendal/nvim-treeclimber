local assert = require("luassert")
local api = require("nvim-treeclimber.api")
local Range = require("nvim-treeclimber.range")

--- @param source string
--- @return string, Range4
local function cursor_pos(str)
  local acc = {}
  local s_row = -1
  local s_col = -1
  local e_row = -1
  local e_col = -1

  for line, _i in string.gmatch(str, "([^\n]+)") do
    -- Match lines that only contain whitespace and ^ or $, lines may contain ^ and $
    if string.match(line, "^%s*[%^%$]%s*[%^%$]?%s*$") then
      local col

      col = string.find(line, "^", 1, true)
      if col then
        s_row = #acc - 1
        s_col = col - 1
        e_row = #acc - 1
        e_col = col
      end

      col = string.find(line, "$", 1, true)
      if col then
        e_row = #acc - 1
        e_col = col - 1
      end
    else
      table.insert(acc, line)
    end
  end

  return table.concat(acc, "\n"), { s_row, s_col, e_row, e_col }
end

local function dedent(term)
  local lines = vim.split(term, "\n", {})
  local indent = nil

  for _, line in ipairs(lines) do
    -- Find the first line that has a non-whitespace character
    local match = string.match(line, "^(%s*)%S")
    if match then
      indent = #match + 1
      break
    end
  end

  if indent == nil then
    return term
  end

  for i, line in ipairs(lines) do
    lines[i] = string.sub(line, indent)
  end

  return table.concat(lines, "\n")
end

local function buf(str)
  return cursor_pos(dedent(str))
end

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
    local expected_range, _
    local source = buf([[
      local a = 1
    ]])

    local actual = parse(source):root()

    actual = api.node.shrink(actual, {})
    assert(actual)

    _, expected_range = buf([[
      local a = 1
            ^    $
    ]])
    assert.are_same(expected_range, { actual:range() })

    _, expected_range = buf([[
      local a = 1
            ^
    ]])
    actual = api.node.shrink(actual, {})
    assert(actual)
    assert.are_same(expected_range, { actual:range() })

    -- Can't shrink further
    actual = api.node.shrink(actual, {})
    assert(actual)
    assert.are_same(expected_range, { actual:range() })
  end)
end)

describe("test helpers", function()
  it("dedent works", function()
    local str

    str = [[


      local a = 1
    ]]
    assert.are.equal(
      dedent(str),
      table.concat({
        "",
        "",
        "local a = 1",
        "",
      }, "\n")
    )

    str = [[
      local a = 1
    ]]
    assert.are.equal(dedent(str), "local a = 1\n")

    str = [[
      local a = 1
        local b = 2
    ]]
    assert.are.equal(dedent(str), "local a = 1\n  local b = 2\n")

    str = [[
      local a = 1
      local b = 2
    ]]
    assert.are.equal(dedent(str), "local a = 1\nlocal b = 2\n")
  end)

  it("cursor_pos works", function()
    local text, range, source

    source = vim.fn.join({
      "local a = 1",
      "      ^",
    }, "\n")
    text, range = cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 7 })


    source = vim.fn.join({
      "local a = 1",
      "      ^$",
    }, "\n")
    text, range = cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 7 })

    source = vim.fn.join({
      "local a = 1",
      "      ^   $",
    }, "\n")
    text, range = cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 10 })

    source = vim.fn.join({
      "function add(x, y)",
      "^",
      "  return x + y",
      "end",
      "  $",
    }, "\n")
    text, range = cursor_pos(source)
    assert.are.equal(text, "function add(x, y)\n  return x + y\nend")
    assert.are.same(range, { 0, 0, 2, 2 })
  end)
end)
