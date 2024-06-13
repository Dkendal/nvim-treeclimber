local M = {}

local a = vim.api

local function win_find_buf(buf)
	local acc = {}
	for _, win in ipairs(a.nvim_list_wins()) do
		if buf == a.nvim_win_get_buf(win) then
			table.insert(acc, win)
		end
	end
	return acc
end

---@param name string
---@return integer | nil
local function find_buf(name)
	for _, buf in ipairs(a.nvim_list_bufs()) do
		if a.nvim_buf_is_loaded(buf) and a.nvim_buf_get_name(buf) == name then
			return buf
		end
	end
	return nil
end

---@param logger_name string
function M.new(logger_name)
	local t = {}

	t.buf_name = "log://[" .. logger_name .. "]"

	function t.clear()
		local buf = find_buf(t.buf_name)

		if buf then
			a.nvim_buf_set_lines(buf, 0, -1, false, {})
		end
	end

	function t.log(...)
		local buf = find_buf(t.buf_name)

		if not buf then
			buf = a.nvim_create_buf(true, true)
			a.nvim_buf_set_name(buf, t.buf_name)
		end

		local tbl = { ... }

		tbl = vim.iter(vim.tbl_map(function(s)
			return vim.split(s, "\n", { plain = true })
		end, tbl)):flatten():totable()

		a.nvim_buf_set_lines(buf, -1, -1, false, tbl)

		for _, win in ipairs(win_find_buf(buf)) do
			local n = a.nvim_buf_line_count(buf)
			a.nvim_win_set_cursor(win, { n, 0 })
		end
	end

	return t
end

-- Write `msg` to the buffer named "[Lua Log]"

return M
