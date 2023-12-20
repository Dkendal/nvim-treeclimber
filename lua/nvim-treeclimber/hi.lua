local hsluv = require("nvim-treeclimber.vivid.hsluv.type")
local hsl = require("nvim-treeclimber.vivid.hsl.type")

local M = {}

---@class Highlight
---@field bg number
---@field fg number
---@field ctermbg number
---@field ctermfg number

---@param name string
---@return Highlight
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

---@param name string
---@return Highlight
--- Returns the highlight group with the given name or the default value if it doesn't exist
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

M.HSLUVHighlight = {}

function M.HSLUVHighlight:new(hl)
	return {
		bg = M.base_ten_to_hsluv(hl.bg),
		fg = M.base_ten_to_hsluv(hl.fg),
		ctermbg = hl.ctermbg,
		ctermfg = hl.ctermfg,
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

function M.ansi_colors()
	local t = {}

	for i = 0, 15 do
		---@type string
		local value = vim.g["terminal_color_" .. i]

		if value then
			t[i] = hsl(value)
		end
	end

	return t
end

return M
