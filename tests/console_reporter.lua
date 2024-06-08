-- Accept a file name from the script args, print line by line
-- to the console.

local flag_coverage = false

-- It's easier to check this in lua than in bash
for _i, v in ipairs(arg) do
	if v == "--coverage" then
		flag_coverage = true
	end
end

if not flag_coverage then
	os.exit(0)
end

local filename = arg[1]

if not filename then
	print("Usage: lua console_reporter.lua <filename>")
	os.exit(1)
end

local file = io.open(filename, "r")

if not file then
	print("Could not open file: " .. filename)
	os.exit(1)
end

local printing = false

for line in file:lines() do
	if line:find("^Summary$") then
		printing = true
		print("")
		print("==============================================================================")
	end

	if printing then
		print(line)
	end
end
