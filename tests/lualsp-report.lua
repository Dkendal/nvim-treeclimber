local path = arg[1]

local file = io.open(path, "r")

if not file then
	print("File not found")
	os.exit(1)
end

local json = vim.json.decode(file:read("*a"))

for f, diagnostics in pairs(json) do
	-- remove leading "file://"
	local localpath = string.sub(f, 8)
	local localpath_ = vim.fn.fnamemodify(localpath, ":~:.")
	assert(localpath_)
	localpath = localpath_

	if localpath:match(".tests/") then
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
				localpath,
				diagnostic.range.start.line,
				diagnostic.range.start.character,
				vim.diagnostic.severity[diagnostic.severity],
				message
			)
		)
	end

	::continue::
end
