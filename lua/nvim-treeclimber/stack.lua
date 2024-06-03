local stack = {}

function stack.push(item)
	table.insert(stack, item)
end

function stack.pop()
	return table.remove(stack)
end

return stack
