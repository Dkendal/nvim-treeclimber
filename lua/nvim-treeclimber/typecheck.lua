local success, typecheck = pcall(require, "typecheck")

---@class treeclimber.typecheck
---@field argcheck fun(name: string, i: integer, expected: string, value: any): boolean
---@field check fun(expected: string, argu: table, i: integer, predicate: fun(term: any): boolean): boolean
local M = {}

if success then
	M = typecheck
else
	M.argcheck = function()
		return true
	end

	M.check = function()
		return true
	end
end

return M
