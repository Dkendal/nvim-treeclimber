local hsluv = require("nvim-treeclimber.vivid.hsluv.type")
local hsl = require("nvim-treeclimber.vivid.hsl.type")

local M = {}

---@alias Highlight vim.api.keyset.hl_info

---@param name string
---@return vim.api.keyset.hl_info
function M.fetch_hl(name, opts)
	opts = opts or {}
	local hl = vim.api.nvim_get_hl(0, { name = name })

	if vim.tbl_isempty(hl) then
		error("hi " .. name .. " not found")
	end

	if opts.follow and hl.link then
		return M.fetch_hl(hl.link, opts)
	end

	return hl
end

--- Returns the highlight group with the given name or the default value if it doesn't exist
---@param name string
---@return vim.api.keyset.hl_info
function M.get_hl(name, opts)
	opts = opts or {}

	local hl = vim.api.nvim_get_hl(0, { name = name })

	if vim.tbl_isempty(hl) then
		return opts.default
	end

	if opts.follow and hl.link then
		return M.get_hl(hl.link, opts)
	end

	return hl
end

---@class HSLUVHighlight
---@field bg? HSLUV
---@field fg? HSLUV
---@field ctermbg? HSLUV
---@field ctermfg? HSLUV

M.HSLUVHighlight = {}

---@param hl Highlight
---@return HSLUVHighlight
function M.HSLUVHighlight:new(hl)
	return {
		bg = hl.bg and M.base_ten_to_hsluv(hl.bg) or nil,
		fg = hl.fg and M.base_ten_to_hsluv(hl.fg) or nil,
	}
end

---@param num number
---@return string
function M.base_ten_to_hex(num)
	if not type(num) == "number" then
		error("num must be a number, got " .. type(num))
	end

	return string.format("#%06x", num)
end

-- Deprecated
M.to_hex = M.base_ten_to_hex

function M.base_ten_to_hsluv(color)
	return hsluv(M.base_ten_to_hex(color))
end

-- Deprecated
M.hsluv = M.base_ten_to_hsluv

function M.get_color_by_name(name)
	return hsl(M.to_hex(vim.api.nvim_get_color_by_name(name)))
end

function M.hsl(color)
	return hsl(M.to_hex(color))
end

function M.bg_hsluv(name)
	local hl = M.fetch_hl(name)
	return M.hsluv(hl.bg)
end

function M.fg_hsluv(name)
	local hl = M.fetch_hl(name)
	return M.hsluv(hl.fg)
end

function M.bg_hsl(name)
	local hl = M.fetch_hl(name)
	return M.hsluv(hl.fg)
end

function M.fg_hsl(name)
	local hl = M.fetch_hl(name)
	return M.hsluv(hl.fg)
end

return M
