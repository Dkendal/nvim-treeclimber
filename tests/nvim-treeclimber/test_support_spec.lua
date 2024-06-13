local t = require("nvim-treeclimber.test_support")

describe("dedent/1", function()
  it("removes the first leading indentation", function()
    local str

    str = [[


      local a = 1
    ]]
    assert.are.equal(
      t:dedent(str),
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
    assert.are.equal(t:dedent(str), "local a = 1\n")

    str = [[
      local a = 1
        local b = 2
    ]]
    assert.are.equal(t:dedent(str), "local a = 1\n  local b = 2\n")

    str = [[
      local a = 1
      local b = 2
    ]]
    assert.are.equal(t:dedent(str), "local a = 1\nlocal b = 2\n")
  end)
end)

describe("cursor_pos/1", function()
  it("returns a range indicated by the `^` and `$` characters", function()
    local text, range, source

    source = vim.fn.join({
      "local a = 1",
      "      ^",
    }, "\n")
    text, range = t:cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 7 })

    source = vim.fn.join({
      "local a = 1",
      "      ^$",
    }, "\n")
    text, range = t:cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 8 })

    source = vim.fn.join({
      "local a = 1",
      "      ^   $",
    }, "\n")
    text, range = t:cursor_pos(source)
    assert.are.equal(text, "local a = 1")
    assert.are.same(range, { 0, 6, 0, 11 })

    source = vim.fn.join({
      "function add(x, y)",
      "^",
      "  return x + y",
      "end",
      "  $",
    }, "\n")
    text, range = t:cursor_pos(source)
    assert.are.equal(text, "function add(x, y)\n  return x + y\nend")
    assert.are.same(range, { 0, 0, 2, 3 })
  end)
end)
