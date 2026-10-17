--!strict

-- Runs every test/**/*Test.luau suite. Pass names to run only the suites or tests whose name contains
-- one of them:
--   lune run test
--   lune run test StringReaderTest CommandDispatcherTest.testExecute

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local JUnit = require("@test/lib/JUnit")

local ROOT = "test"

local function findSuites(directory: string, found: { string })
	local entries = fs.readDir(directory)
	table.sort(entries)
	for _, entry in entries do
		local path = `{directory}/{entry}`
		if fs.isDir(path) then
			if path ~= `{ROOT}/lib` then
				findSuites(path, found)
			end
		elseif entry:match("Test%.luau$") then
			table.insert(found, path)
		end
	end
end

local filters = process.args
local function selected(suiteName: string, testName: string): boolean
	if #filters == 0 then
		return true
	end
	local full = `{suiteName}.{testName}`
	for _, filter in filters do
		if full:find(filter, 1, true) then
			return true
		end
	end
	return false
end

local function formatError(err: unknown): string
	if type(err) == "table" and type((err :: any).getMessage) == "function" then
		return `{tostring(err)}: {(err :: any):getMessage()}`
	end
	return tostring(err)
end

local paths = {}
findSuites(ROOT, paths)

local passed, failed = 0, 0
local failures: { string } = {}

for _, path in paths do
	local modulePath = "@" .. path:gsub("%.luau$", "")
	local loaded, suite = pcall(require, modulePath)
	if not loaded then
		failed += 1
		table.insert(failures, `{path}: failed to load\n{suite}`)
		continue
	end
	local typedSuite = suite :: JUnit.Suite
	for _, test in typedSuite.tests do
		if not selected(typedSuite.name, test.name) then
			continue
		end
		local traceback: string? = nil
		local err: unknown = nil
		local ok = xpcall(function()
			for _, hook in typedSuite.befores do
				hook()
			end
			test.run()
		end, function(raised)
			err = raised
			traceback = debug.traceback(nil, 2)
		end)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, `{typedSuite.name}.{test.name}\n{formatError(err)}\n{traceback or ""}`)
		end
	end
end

for _, failure in failures do
	print(stdio.color("red") .. "FAIL " .. stdio.color("reset") .. failure)
end

local summary = `{passed} passed, {failed} failed`
if failed > 0 then
	print(stdio.color("red") .. summary .. stdio.color("reset"))
	process.exit(1)
end
print(stdio.color("green") .. summary .. stdio.color("reset"))
