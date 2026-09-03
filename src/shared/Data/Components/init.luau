--!strict
--[[
	init.luau — จุดรวมแคตตาล็อกชิ้นส่วนทั้ง 7 หมวดไว้ที่เดียว

	ใช้งาน:
		local Components = require(ReplicatedStorage.Shared.Data.Components)
		Components.CPU                      -- { Types.CPU } ทั้งหมด
		Components.getByCategory("GPU")     -- { Types.AnyPart } เฉพาะหมวดนั้น
		Components.getById("cpu_r5_7600")   -- Types.AnyPart? (nil ถ้าไม่เจอ)
		Components.getAll()                 -- { Types.AnyPart } ทุกหมวดรวมกัน

	เรื่อง require: ไฟล์นี้ require แค่ Types ตัวเดียว (จำเป็นเพราะต้องใส่ type
	ให้ helper ทั้ง 3 ตัวตามกฎในโปรเจค) และไม่ require Enums เลย
	กราฟ require เป็นเส้นตรง ไม่มีวงจร:
		Components/init -> Types -> Enums   (Enums ไม่ require อะไรต่อ)
		Components/CPU  -> Types -> Enums   (เหมือนกันทุกหมวด)
	Types และ Enums ไม่รู้จัก Components เลย จึงวนกลับมาไม่ได้

	หมายเหตุ Rojo: การมี init.luau ทำให้ Components กลายเป็น ModuleScript
	และไฟล์ทั้ง 7 กลายเป็น "ลูก" ของมัน แต่ความลึกของ path เท่าเดิม
	script.Parent.Parent.Parent.Types ในไฟล์หมวดต่าง ๆ จึงยังชี้ถูกเหมือนเดิม
]]

local Types = require(script.Parent.Parent.Types)

local CPUs = require(script.CPU)
local Mainboards = require(script.Mainboard)
local RAMs = require(script.RAM)
local GPUs = require(script.GPU)
local Storages = require(script.Storage)
local PSUs = require(script.PSU)
local Cases = require(script.Case)

-- ตารางค้นหาที่สร้างครั้งเดียวตอนโหลด module (helper จึงเป็น O(1) / O(n) ไม่ใช่ค้นซ้ำทุกครั้ง)
local byCategory: { [Types.Category]: { Types.AnyPart } } = {}
local byId: { [string]: Types.AnyPart } = {}
local allParts: { Types.AnyPart } = {}

-- ตารางว่างที่ freeze ไว้ ใช้คืนค่าเมื่อหาไม่เจอ จะได้ไม่ต้องสร้าง table ใหม่ทุกครั้ง
local EMPTY: { Types.AnyPart } = table.freeze({})

local function add(category: Types.Category, part: Types.AnyPart)
	-- id ซ้ำจะทำให้ getById คืนของผิดตัวแบบเงียบ ๆ จับให้เจอตั้งแต่ตอนโหลด
	assert(byId[part.id] == nil, `Components: id ซ้ำ "{part.id}"`)
	assert(part.category == category, `Components: "{part.id}" อยู่ในไฟล์ {category} แต่ category เป็น "{part.category}"`)

	local list = byCategory[category]
	if list == nil then
		list = {}
		byCategory[category] = list
	end

	byId[part.id] = part
	table.insert(list, part)
	table.insert(allParts, part)
end

-- ลำดับการ add คือลำดับที่ getAll() จะคืนค่าเสมอ (คงที่ ไม่ขึ้นกับการวน pairs)
-- เรียงตาม Enums.CategoryList — ถ้าเพิ่มหมวดใหม่ต้องมาเพิ่มบรรทัดตรงนี้ด้วย
for _, part in CPUs do
	add("CPU", part)
end
for _, part in Mainboards do
	add("Mainboard", part)
end
for _, part in RAMs do
	add("RAM", part)
end
for _, part in GPUs do
	add("GPU", part)
end
for _, part in Storages do
	add("Storage", part)
end
for _, part in PSUs do
	add("PSU", part)
end
for _, part in Cases do
	add("Case", part)
end

for _, list in byCategory do
	table.freeze(list)
end
table.freeze(allParts)

local Components = {
	CPU = CPUs,
	Mainboard = Mainboards,
	RAM = RAMs,
	GPU = GPUs,
	Storage = Storages,
	PSU = PSUs,
	Case = Cases,
}

--[[
	คืนชิ้นส่วนทั้งหมดในหมวดที่ระบุ
	ค่าที่คืนเป็นตาราง frozen ตัวเดิมทุกครั้ง (ห้ามแก้ ถ้าจะเรียง/กรอง ให้ copy ก่อน)
	ถ้าส่ง category ที่ไม่รู้จักมา (เช่น string ที่มาจาก client) จะคืนตารางว่าง ไม่ error
]]
local function getByCategory(category: Types.Category): { Types.AnyPart }
	return byCategory[category] or EMPTY
end

-- หาชิ้นส่วนจาก id คืน nil ถ้าไม่มี — ใช้ตอน client ส่ง id ที่เลือกกลับมาให้ server ตรวจ
local function getById(id: string): Types.AnyPart?
	return byId[id]
end

-- ชิ้นส่วนทุกหมวดรวมกัน เรียงตามลำดับหมวด CPU -> Mainboard -> RAM -> GPU -> Storage -> PSU -> Case
local function getAll(): { Types.AnyPart }
	return allParts
end

Components.getByCategory = getByCategory
Components.getById = getById
Components.getAll = getAll

return table.freeze(Components)
