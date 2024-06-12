local file = io.open("./check.json", "r")

if not file then
	print("File not found")
	os.exit(1)
end

local json = vim.json.decode(file:read("*a"))

for file, diagnostics in pairs(json) do
	-- remove leading "file://"
	local path = string.sub(file, 8)
	local path_ = vim.fn.fnamemodify(path, ":~:.")
	assert(path_)
	path = path_

	if path:match(".tests/") then
		goto continue
	end

	for _, diagnostic_ in ipairs(diagnostics) do
		--- @class Diagnostic
		--- @field message integer
		--- @field code integer
		--- @field severity integer
		--- @field source string
		--- @field range { ["end"]: { character: integer, line: integer }, start: { character: integer, line: integer } }
		local diagnostic = diagnostic_
		local message = diagnostic.message:gsub("\n", "; ")
		io.write(
			string.format(
				"%s:%s:%s:%s: %s\n",
				path,
				diagnostic.range.start.line,
				diagnostic.range.start.character,
				vim.diagnostic.severity[diagnostic.severity],
				message
			)
		)
	end

	::continue::
end
