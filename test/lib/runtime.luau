-- Loads compiled roblox-ts output through roblox-ts's runtime, the way a place requires a package from
-- rbxts_include: the folder becomes instances beside the runtime's RuntimeLib and Promise. Returns the module at
-- path under the folder, or the folder itself, which out/'s init.luau makes a ModuleScript.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

type Node = {
	name: string,
	className: string,
	file: string?,
	parent: Node?,
	children: { [string]: Node },
}

local function newNode(name: string, className: string, parent: Node?, file: string?): Node
	local node = { name = name, className = className, parent = parent, file = file, children = {} }
	if parent then
		parent.children[name] = node
	end
	return node
end

local function mount(directory: string, node: Node)
	for _, entry in fs.readDir(directory) do
		local path = `{directory}/{entry}`
		local module = string.match(entry, "^(.+)%.luau?$")
		if fs.isDir(path) then
			mount(path, newNode(entry, "Folder", node))
		elseif entry == "init.luau" or entry == "init.lua" then
			node.className = "ModuleScript"
			node.file = path
		elseif module then
			newNode(module, "ModuleScript", node, path)
		end
	end
end

return function(folder: string, path: { string }, given: { [string]: any }?): any
	local globals = given or {}
	local root = newNode("ReplicatedStorage", "Folder", nil)
	local include = newNode("include", "Folder", root)
	mount("node_modules/roblox-ts/include", include)
	local compiled = newNode("compiled", "Folder", root)
	mount(folder, compiled)

	local instances: { [Node]: any } = {}
	local nodes: { [any]: Node } = {}
	local realm = {}
	local cache: { [Node]: any } = {}

	local function instanceOf(node: Node): any
		local existing = instances[node]
		if existing then
			return existing
		end
		local methods = {}
		function methods.FindFirstChild(_self, name: string)
			local child = node.children[name]
			return if child then instanceOf(child) else nil
		end
		function methods.WaitForChild(self, name: string)
			return methods.FindFirstChild(self, name) or error(`{node.name} has no child {name}`)
		end
		function methods.FindFirstAncestorWhichIsA()
			return nil
		end
		function methods.GetFullName()
			local parts = {}
			local current: Node? = node
			while current do
				table.insert(parts, 1, current.name)
				current = current.parent
			end
			return table.concat(parts, ".")
		end
		local instance = setmetatable({}, {
			__index = function(_self, key: string)
				if methods[key] then
					return methods[key]
				elseif key == "Name" then
					return node.name
				elseif key == "ClassName" then
					return node.className
				elseif key == "Parent" then
					return if node.parent then instanceOf(node.parent) else nil
				end
				return methods.FindFirstChild(nil, key) or error(`{key} is not a valid member of {node.name}`)
			end,
			__tostring = function()
				return node.name
			end,
		})
		instances[node] = instance
		nodes[instance] = node
		return instance
	end

	local RunService = {
		IsRunning = function()
			return false
		end,
		IsStudio = function()
			return false
		end,
		IsClient = function()
			return false
		end,
	}

	local game = {
		GetService = function(_self, name: string)
			assert(name == "RunService", `The package asked for the {name} service`)
			return RunService
		end,
	}

	local function load(node: Node): any
		if cache[node] == nil then
			local file = assert(node.file, `{node.name} is not a ModuleScript`)
			local environment: { [string]: any } = table.clone(globals)
			environment._G = realm
			environment.game = game
			environment.task = task
			environment.script = instanceOf(node)
			environment.require = function(module: any)
				return load(assert(nodes[module], "require expects a ModuleScript"))
			end
			local chunk = luau.load(fs.readFile(file), { debugName = file, environment = environment })
			cache[node] = chunk()
		end
		return cache[node]
	end

	local TS = load(include.children.RuntimeLib)
	return TS.import(instanceOf(root), instanceOf(compiled), table.unpack(path))
end
