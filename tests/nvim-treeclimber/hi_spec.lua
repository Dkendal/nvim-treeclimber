local M = require("nvim-treeclimber.hi")

describe("to_hex", function()
  it("converts a base 10 number to a formatted hex string", function()
    assert.are.equal(M.to_hex(999), "#0003e7")
  end)
end)

describe("fetch_hl", function()
  it("returns the highlight", function()
    vim.api.nvim_set_hl(0, "Test", { background = 999, foreground = 999 })

    local hl = M.fetch_hl("Test")

    assert.are.equal(hl.bg, 999)
  end)
end)
