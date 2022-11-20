local lush = require("lush")
local a = vim.api

local M = {}

function M.hex(num)
	return string.format("#%06x", num)
end

function M.mkhl(ns, name, opts)
	a.nvim_set_hl(0, name, opts)
	return name
end

function M.hsluv(color)
	return lush.hsluv(M.hex(color))
end

function M.get_color_by_name(name)
	return lush.hsl(M.hex(vim.api.nvim_get_color_by_name(name)))
end

function M.hsl(color)
	return lush.hsl(M.hex(color))
end

function M.get_hl(name)
	local t = a.nvim_get_hl_by_name(name, true)

	function t:bg()
		return M.hsluv(t.background)
	end

	function t:fg()
		return M.hsluv(t.foreground)
	end

	return t
end

function M.bg_hsluv(name)
	return M.hsluv(a.nvim_get_hl_by_name(name, true).background)
end

function M.fg_hsluv(name)
	return M.hsluv(a.nvim_get_hl_by_name(name, true).foreground)
end

function M.bg_hsl(name)
	return M.hsl(a.nvim_get_hl_by_name(name, true).background)
end

function M.fg_hsl(name)
	return M.hsl(a.nvim_get_hl_by_name(name, true).foreground)
end

M.terminal_color_0 = lush.hsl(vim.g.terminal_color_0)
M.terminal_color_1 = lush.hsl(vim.g.terminal_color_1)
M.terminal_color_2 = lush.hsl(vim.g.terminal_color_2)
M.terminal_color_3 = lush.hsl(vim.g.terminal_color_3)
M.terminal_color_4 = lush.hsl(vim.g.terminal_color_4)
M.terminal_color_5 = lush.hsl(vim.g.terminal_color_5)
M.terminal_color_6 = lush.hsl(vim.g.terminal_color_6)
M.terminal_color_7 = lush.hsl(vim.g.terminal_color_7)
M.terminal_color_8 = lush.hsl(vim.g.terminal_color_8)
M.terminal_color_9 = lush.hsl(vim.g.terminal_color_9)
M.terminal_color_10 = lush.hsl(vim.g.terminal_color_10)
M.terminal_color_11 = lush.hsl(vim.g.terminal_color_11)
M.terminal_color_12 = lush.hsl(vim.g.terminal_color_12)
M.terminal_color_13 = lush.hsl(vim.g.terminal_color_13)
M.terminal_color_14 = lush.hsl(vim.g.terminal_color_14)
M.terminal_color_15 = lush.hsl(vim.g.terminal_color_15)

return M
