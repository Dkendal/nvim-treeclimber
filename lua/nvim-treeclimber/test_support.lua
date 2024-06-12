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

return test_support