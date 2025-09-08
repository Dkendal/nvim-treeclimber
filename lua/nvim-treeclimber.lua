local M = {}

---@class treeclimber.Config

---@type treeclimber.Config
local default_config = {
}

---@param opts treeclimber.Config
function M.setup(opts)
	vim.g.treeclimber = vim.tbl_deep_extend('force', default_config, opts)
end

return M
