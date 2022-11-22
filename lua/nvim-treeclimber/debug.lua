local M = {}

-- Pretty print a TSNode as a s-expr()
function M.pretty_sexpr(node)
	return M.pretty_sexpr_string(node:sexpr())
end

function M.pretty_sexpr_string(s)
	local sw = 2
	local indent = 0
	local result = ""
	local last_char = ""
	for c in string.gmatch(s, ".") do
		if c == "(" and last_char == "(" then
			indent = indent + sw
			result = result .. c
		elseif c == "(" then
			indent = indent + sw
			result = result .. "\n" .. string.rep(" ", indent) .. c
		elseif c == ")" then
			indent = indent - sw
			result = result .. c
		elseif c == " " then
			result = result .. c
		else
			result = result .. c
		end

		if string.match(c, "%S") then
			last_char = c
		end
	end
	return result
end

return M
