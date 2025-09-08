local M = {}

---@alias treeclimber.Config.highlight boolean | integer | function()

---@class treeclimber.Config
---@field highlight treeclimber.Config.highlight
---
---@class treeclimber.PartialConfig
---@field highlight? treeclimber.Config.highlight
---
---@type treeclimber.Config

local default_config = {
	highlight = {
		auto = true
	}
}

vim.g.treeclimber = vim.tbl_deep_extend('force', {}, default_config)

---@param opts treeclimber.PartialConfig
function M.set_config(opts)
	vim.g.treeclimber = vim.tbl_deep_extend('force', default_config, opts)
end

---@return treeclimber.Config
function M.get_config()
	return vim.g.treeclimber
end

---@param opts treeclimber.PartialConfig
function M.setup(opts)
	M.set_config(opts)
end

function M.setup_highlights()
	local config = M.get_config()

	local opt = config.highlight

	if opt == false then
		return
	end

	if opt == true then
		-- Default blend value
		opt = 50
	end

	if type(opt) == "number" then
		local hi = require("nvim-treeclimber.hi")

		local Normal = hi.get_hl("Normal", { follow = true })
		assert(not vim.tbl_isempty(Normal), "hi Normal not found")
		local normal = hi.HSLUVHighlight:new(Normal)

		local Visual = hi.get_hl("Visual", { follow = true })
		assert(not vim.tbl_isempty(Visual), "hi Visual not found")
		local visual = hi.HSLUVHighlight:new(Visual)

		local set_hl = vim.api.nvim_set_hl
		set_hl(0, "TreeClimberSiblingBoundary", { background = visual.bg.mix(normal.bg, opt).hex })
		set_hl(0, "TreeClimberSibling", { background = visual.bg.mix(normal.bg, opt).hex })
		set_hl(0, "TreeClimberParent", { background = visual.bg.mix(normal.bg, opt).hex })
		set_hl(0, "TreeClimberParentStart", { background = visual.bg.mix(normal.bg, opt).hex })

		return
	end

	if type(opt) == "function" then
		opt()
		return
	end
end

return M
