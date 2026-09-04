--!strict
--[[
	devtest.luau — ตัวรัน DevTest นอก Roblox Studio ด้วย lune
	รัน:  lune run devtest.luau [path ของโปรเจค]

	มันทำอะไร: จำลอง instance tree ของ Roblox จากโครงสร้างไฟล์ใน src/
	แล้ว require โมดูลจริง ๆ ด้วย environment ที่มี script / game / Random ปลอมให้

	⚠️ ข้อจำกัดสำคัญ: Random ในนี้ไม่ใช่ตัวเดียวกับ Roblox
	เทสที่อ่านข้อมูลจากแคตตาล็อกตรง ๆ (ข้อ 4-7) จะได้ผลเหมือน Studio เป๊ะ
	แต่ข้อ 1-3 กับ 8 ที่ใช้การสุ่ม จะได้โจทย์คนละชุดกับ Studio
	(เปอร์เซ็นต์ข้อ 8 ควรใกล้เคียงกัน แต่ไม่เท่ากันเป๊ะ)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local root = process.args[1] or process.cwd
root = string.gsub(root, "\\", "/")
root = string.gsub(root, "/+$", "")

----------------------------------------------------------------------
-- Random ปลอม (xorshift32) — deterministic แต่คนละสูตรกับ Roblox
----------------------------------------------------------------------
local FakeRandom = {}

local function newRandom(seed: number?)
	local state = bit32.band(math.floor(seed or 0), 0xFFFFFFFF)
	state = bit32.bxor(state, 0x9E3779B9)
	if state == 0 then
		state = 1
	end

	local function nextUInt(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state
	end

	local self = {}

	function self:NextNumber(min: number?, max: number?): number
		local unit = nextUInt() / 4294967296
		if min == nil or max == nil then
			return unit
		end
		return min + (max - min) * unit
	end

	function self:NextInteger(min: number, max: number): number
		return min + (nextUInt() % (max - min + 1))
	end

	return self
end

FakeRandom.new = newRandom

----------------------------------------------------------------------
-- instance tree ปลอม สร้างจากโครงสร้างไฟล์
----------------------------------------------------------------------
type Node = any

local function newNode(name: string, parent: Node?): Node
	local node = { Name = name, Parent = parent, _children = {} }
	setmetatable(node, {
		__index = function(t, key)
			local child = rawget(t, "_children")[key]
			if child ~= nil then
				return child
			end
			error(string.format('instance "%s" ไม่มีลูกชื่อ "%s"', tostring(rawget(t, "Name")), tostring(key)), 2)
		end,
		__tostring = function(t)
			return rawget(t, "Name")
		end,
	})
	if parent ~= nil then
		rawget(parent, "_children")[name] = node
	end
	return node
end

-- โฟลเดอร์ที่มี init.luau จะกลายเป็น ModuleScript เอง (กฎเดียวกับ Rojo)
local function loadDir(path: string, name: string, parent: Node?): Node
	local node = newNode(name, parent)
	for _, entry in fs.readDir(path) do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			loadDir(full, entry, node)
		elseif string.match(entry, "%.luau$") then
			local base = string.gsub(entry, "%.luau$", "")
			base = string.gsub(base, "%.server$", "")
			base = string.gsub(base, "%.client$", "")
			if base == "init" then
				rawset(node, "_file", full)
			else
				local child = newNode(base, node)
				rawset(child, "_file", full)
			end
		end
	end
	return node
end

local ReplicatedStorage = newNode("ReplicatedStorage", nil)
loadDir(root .. "/src/shared", "Shared", ReplicatedStorage)

local ServerScriptService = newNode("ServerScriptService", nil)
loadDir(root .. "/src/server", "Server", ServerScriptService)

local services: { [string]: Node } = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
}

local fakeGame = {}
function fakeGame:GetService(serviceName: string): Node
	local service = services[serviceName]
	if service == nil then
		error("ตัวรันนี้ยังไม่รองรับ service: " .. serviceName, 2)
	end
	return service
end

----------------------------------------------------------------------
-- require ที่รับ instance ปลอม
----------------------------------------------------------------------
local loaded: { [any]: boolean } = {}
local results: { [any]: any } = {}
local moduleRequire

local function warnShim(...)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	print("[warn] " .. table.concat(parts, " "))
end

moduleRequire = function(target: Node): any
	if type(target) ~= "table" then
		error("require ต้องรับ instance ปลอมเท่านั้น ไม่ใช่ " .. type(target), 2)
	end
	if loaded[target] then
		return results[target]
	end

	local file = rawget(target, "_file")
	if file == nil then
		error(string.format('"%s" ไม่ใช่ ModuleScript (ไม่มีไฟล์)', tostring(rawget(target, "Name"))), 2)
	end

	local chunk = luau.load(fs.readFile(file), {
		debugName = string.gsub(file, "^" .. string.gsub(root, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "/", ""),
		environment = {
			script = target,
			require = moduleRequire,
			game = fakeGame,
			Random = FakeRandom,
			warn = warnShim,
			task = { wait = function() end, spawn = function(fn, ...) fn(...) end },
		},
		injectGlobals = true,
	})

	local result = chunk()
	loaded[target] = true
	results[target] = result
	return result
end

----------------------------------------------------------------------
-- รัน
----------------------------------------------------------------------
print("===============================================================")
print("  รัน DevTest นอก Studio ด้วย lune")
print("  โปรเจค: " .. root)
print("  ⚠️ Random ไม่ใช่ตัวเดียวกับ Roblox ผลข้อ 1-3 และ 8 จะต่างจาก Studio")
print("===============================================================")
print("")

local DevTest = moduleRequire(ServerScriptService.Server.Systems.DevTest)
local passed = DevTest.run()

print("")
print("===============================================================")
if passed then
	print("  ✔ DevTest.run() คืนค่า true — ไม่พบปัญหา")
else
	print("  ✘ DevTest.run() คืนค่า false — มีปัญหา ดู [warn] ด้านบน")
end
print("===============================================================")

process.exit(if passed then 0 else 1)
