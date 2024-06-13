local test_support = {}

--- @param str string
--- @return string, Range4
function test_support:cursor_pos(str)
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

function test_support:dedent(term)
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

function test_support:parse(source)
	---@type vim.treesitter.LanguageTree
	local lt = vim.treesitter.get_string_parser(source, "lua")
	---@type TSTree?
	local tree = lt:parse()[1]

	if tree == nil then
		error("Failed to parse")
	end

	return tree
end

function test_support:buf(str)
	local source, range = self:cursor_pos(self:dedent(str))
	local tree = self:parse(source)
	local node = tree:root():named_descendant_for_range(unpack(range))
	return source, range, node, tree
end

function test_support:with_buffer(opts)
	local callback = opts.callback
	local text = opts.text
	local filetype = opts.filetype or "lua"
	local mode = opts.mode or "n"

	local buf = vim.api.nvim_create_buf(true, false)

	local function buf_function()
		vim.bo.filetype = filetype

		local buffer_text, initial_cursor = test_support:buf(text)

		local lines = vim.split(buffer_text, "\n")

		vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

		-- This api is 1-indexed
		vim.api.nvim_win_set_cursor(0, { initial_cursor[1] + 1, initial_cursor[2] })

		if mode == "v" then
			vim.api.nvim_buf_set_mark(0, ">", initial_cursor[1] + 1, initial_cursor[2], {})
			vim.api.nvim_buf_set_mark(0, "<", initial_cursor[3] + 1, initial_cursor[4], {})
			vim.cmd("normal! gv")
			assert(vim.api.nvim_get_mode().mode == "v", "Failed to enter visual mode")
		end

		callback()

		local final_mode = vim.api.nvim_get_mode().mode
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line_v = vim.fn.line("v")
		local col_v = vim.fn.col("v")

		local state = {
			buf = buf,
			mode = final_mode,
			cursor = cursor,
			line_v = line_v,
			col_v = col_v,
		}

		function state:lines()
			return vim.api.nvim_buf_get_lines(buf, 0, -1, true)
		end

		function state:delete()
			vim.api.nvim_buf_delete(buf, { force = true })
		end

		function state:selected_text()
			-- This api is 0-indexed
			return vim.api.nvim_buf_get_text(
				self.buf,
				self.cursor[1] - 1,
				self.cursor[2],
				self.line_v - 1,
				self.col_v,
				{}
			)
		end

		return state
	end

	local success, result = unpack(vim.api.nvim_buf_call(buf, function()
		local bf_success, bf_result = xpcall(buf_function, function(err)
			return err
		end)

		return { bf_success, bf_result }
	end))

	if not success then
		-- Bubble any errors up
		if result.message then
			error(result.message)
		else
			error(result)
		end
	end

	return result
end

return test_support
