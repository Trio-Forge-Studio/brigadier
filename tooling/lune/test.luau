-- Runs every spec in the package's test/ against its compiled out/. Build it first with `pnpm run build`.
-- Pass names to run only the specs or tests whose name contains one of them. Lune resolves a require from the
-- file that calls it, so each package passes its own loadSpec.
local fs = require("@lune/fs")
local process = require("@lune/process")

return function(loadSpec: (string) -> { [string]: () -> () })
	local filters = process.args
	local function wanted(name: string): boolean
		if #filters == 0 then
			return true
		end
		for _, filter in filters do
			if string.find(name, filter, 1, true) then
				return true
			end
		end
		return false
	end

	local files = fs.readDir("test")
	table.sort(files)
	local passed, failed = 0, 0
	for _, file in files do
		if string.match(file, "%.luau$") then
			local tests = loadSpec(string.sub(file, 1, -6))
			local names = {}
			for name in tests do
				if wanted(`{file}: {name}`) then
					table.insert(names, name)
				end
			end
			table.sort(names)
			for _, name in names do
				local ok, message = pcall(tests[name])
				if ok then
					passed += 1
				else
					failed += 1
					print(`FAIL {file}: {name}\n{message}`)
				end
			end
		end
	end

	print(`{passed} passed, {failed} failed`)
	process.exit(if failed == 0 then 0 else 1)
end
