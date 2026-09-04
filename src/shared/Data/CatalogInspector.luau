--!strict
--[[
	CatalogInspector.luau — เครื่องมือถามแคตตาล็อกว่า "สเปกที่ลูกค้าขอ มีของขายจริงไหม"

	ใช้กฎ tolerance เดียวกับตอนออกแบบข้อมูล: ชิ้นส่วนถือว่า "ตรงเป้า" เมื่อ
		target * (1 - tolerance) <= perfScore <= target * (1 + tolerance)
	ค่าเริ่มต้น tolerance = 0.2 (±20%)

	ใช้ได้ทั้งใน DevTest (ตรวจว่าแคตตาล็อกมีรูโหว่ไหม) และในระบบจริง
	(กรองโจทย์ที่แก้ไม่ได้ทิ้งก่อนส่งให้ผู้เล่น)

	กรณีพิเศษ GPU ค่าน้อย ๆ:
	SoftwareRequirements ใช้ GPU = 0 หมายถึง "การ์ดจอออนบอร์ดเอาอยู่" แต่ซอฟต์แวร์ที่
	minSpec.GPU = 0 และ recommendedSpec.GPU > 0 (เช่น Roblox, Ourcraft) ทำให้โจทย์
	สุ่มออกมาได้ targetSpec.GPU = 1-9 ซึ่งไม่ใช่ 0 พอดี
	ค่าพวกนี้หาการ์ดมาตอบไม่ได้เลย เพราะ ±20% ของ 2 คือหน้าต่างกว้างแค่ ±0.4
	ยิ่งเข้าใกล้ 0 หน้าต่างยิ่งแคบ ต่อให้เพิ่มการ์ดอีกกี่ใบก็ปิดรูไม่ได้

	ตัวตรวจนี้จึงถือว่า "ขอ GPU ต่ำกว่าหรือเท่ากับการ์ดที่อ่อนที่สุดในร้าน = ไม่ต้องซื้อการ์ดแยก"
	แล้วนับว่าผ่านถ้ามีซีพียูที่ hasIGPU = true อยู่ในแคตตาล็อก
	เพดานนี้คำนวณจากข้อมูลจริง ถ้าวันหลังเพิ่มการ์ดที่อ่อนกว่าเดิม มันจะขยับตามเอง
]]

local Types = require(script.Parent.Parent.Types)
local Components = require(script.Parent.Components)

local DEFAULT_TOLERANCE = 0.2

-- PSU ต้องจ่ายไฟได้อย่างน้อยกี่เท่าของที่ชุดนั้นกินจริง (เผื่อหัวไว้ 20%)
local PSU_HEADROOM = 1.2

-- 4 หมวดที่ SpecProfile พูดถึง (อีก 3 หมวดคือ Mainboard/PSU/Case ไม่มีใน targetSpec)
local SPEC_CATEGORIES: { Types.Category } = table.freeze({ "CPU", "GPU", "RAM", "Storage" })

-- นับซีพียูที่มีการ์ดจอในตัว คำนวณครั้งเดียวตอนโหลด ใช้ตัดสินกรณี GPU ค่าน้อย ๆ
local igpuCount = 0
for _, cpu in Components.CPU do
	if cpu.hasIGPU then
		igpuCount += 1
	end
end

-- perfScore ของการ์ดจอที่อ่อนที่สุดในร้าน = เพดานที่ถือว่า "ไม่ต้องซื้อการ์ดจอแยก"
local igpuMaxTarget = 0
for index, gpu in Components.GPU do
	if index == 1 or gpu.perfScore < igpuMaxTarget then
		igpuMaxTarget = gpu.perfScore
	end
end

-- ชุดคอมพิวเตอร์ที่ถูกที่สุดที่ตอบโจทย์ได้ครบทั้ง 7 หมวด (GPU = nil คือใช้การ์ดจอออนบอร์ด)
export type ReferenceBuild = {
	CPU: Types.CPU,
	Mainboard: Types.Mainboard,
	RAM: Types.RAM,
	GPU: Types.GPU?,
	Storage: Types.Storage,
	PSU: Types.PSU,
	Case: Types.Case,
	totalPrice: number,
}

export type SpecCoverage = {
	ok: boolean,                                -- true = ครบทุกหมวด หาของได้หมด
	missing: { Types.Category },                -- หมวดที่หาของไม่เจอ (เรียงตาม SPEC_CATEGORIES)
	matchCount: { [Types.Category]: number },   -- จำนวนชิ้นที่เข้าเกณฑ์ของแต่ละหมวด
}

local CatalogInspector = {
	DEFAULT_TOLERANCE = DEFAULT_TOLERANCE,
	SPEC_CATEGORIES = SPEC_CATEGORIES,
	IGPU_MAX_TARGET = igpuMaxTarget,
}

-- SpecProfile มี key คงที่ 4 ตัว แต่ strict mode ไม่ยอมให้ index ด้วยตัวแปร เลยต้อง cast
local function specValue(spec: Types.SpecProfile, category: Types.Category): number
	return (spec :: any)[category]
end

--[[
	หาชิ้นส่วนในหมวดที่ perfScore อยู่ในช่วง ±tolerance ของเป้าหมาย
	คืนตารางใหม่เสมอ (เรียงตามลำดับในแคตตาล็อก) แก้ไขได้ไม่กระทบข้อมูลกลาง
]]
function CatalogInspector.findWithinTolerance(
	category: Types.Category,
	target: number,
	tolerance: number?
): { Types.AnyPart }
	local margin = tolerance or DEFAULT_TOLERANCE
	local low = target * (1 - margin)
	local high = target * (1 + margin)

	local found: { Types.AnyPart } = {}
	for _, part in Components.getByCategory(category) do
		if part.perfScore >= low and part.perfScore <= high then
			table.insert(found, part)
		end
	end

	return found
end

-- มีของขายที่ตรงเป้าหมายนี้อย่างน้อย 1 ชิ้นไหม (GPU = 0 คิดกรณี iGPU ให้ด้วย)
function CatalogInspector.hasPartFor(category: Types.Category, target: number, tolerance: number?): boolean
	if category == "GPU" and target <= igpuMaxTarget then
		return igpuCount > 0
	end
	return #CatalogInspector.findWithinTolerance(category, target, tolerance) > 0
end

--[[
	ไล่หาช่วงเป้าหมายที่ "ไม่มีของขาย" ในหมวดหนึ่ง
	เช่น findCoverageGaps("CPU", 10, 90, 5) = ไล่ target 10,15,...,90
	คืนลิสต์ target ที่หาของไม่เจอ ถ้าว่างแปลว่าครอบคลุมครบ
]]
function CatalogInspector.findCoverageGaps(
	category: Types.Category,
	from: number,
	to: number,
	step: number,
	tolerance: number?
): { number }
	local gaps: { number } = {}
	for target = from, to, step do
		if not CatalogInspector.hasPartFor(category, target, tolerance) then
			table.insert(gaps, target)
		end
	end
	return gaps
end

--[[
	ตรวจ targetSpec ของโจทย์ 1 ใบว่ามีชิ้นส่วนรองรับครบทั้ง 4 หมวดไหม
	ใช้ตัดสินว่าโจทย์ใบนั้น "แก้ได้จริง" หรือเปล่า
]]
function CatalogInspector.checkSpec(spec: Types.SpecProfile, tolerance: number?): SpecCoverage
	local missing: { Types.Category } = {}
	local matchCount: { [Types.Category]: number } = {}

	for _, category in SPEC_CATEGORIES do
		local target = specValue(spec, category)
		local count

		if category == "GPU" and target <= igpuMaxTarget then
			count = igpuCount -- การ์ดจอออนบอร์ดเอาอยู่ นับซีพียูที่มี iGPU แทน
		else
			count = #CatalogInspector.findWithinTolerance(category, target, tolerance)
		end

		matchCount[category] = count
		if count == 0 then
			table.insert(missing, category)
		end
	end

	return {
		ok = #missing == 0,
		missing = missing,
		matchCount = matchCount,
	}
end

--[[
	หาชิ้นส่วนที่ perfScore ใกล้เป้าหมายที่สุด (ไม่สนว่าจะหลุดเกณฑ์ ±tolerance หรือไม่)
	ถ้าใกล้เท่ากันหลายชิ้น เอาชิ้นที่ถูกกว่า ผลจึงคงที่ทุกครั้ง
	ใช้เป็นตัวสำรองตอนไม่มีชิ้นไหนเข้าเกณฑ์เลย
]]
function CatalogInspector.findClosest(category: Types.Category, target: number): Types.AnyPart?
	local best: Types.AnyPart? = nil
	local bestDiff = math.huge

	for _, part in Components.getByCategory(category) do
		local diff = math.abs(part.perfScore - target)
		if diff < bestDiff or (diff == bestDiff and best ~= nil and part.price < best.price) then
			bestDiff = diff
			best = part
		end
	end

	return best
end

-- ชิ้นส่วนที่เข้าเกณฑ์ เรียงจากถูกไปแพง (id เป็นตัวตัดสินตอนราคาเท่ากัน ผลจะได้เหมือนเดิมทุกรอบ)
local function cheapestFirst(category: Types.Category, target: number, margin: number): { Types.AnyPart }
	local found = CatalogInspector.findWithinTolerance(category, target, margin)

	if #found == 0 then
		local fallback = CatalogInspector.findClosest(category, target)
		if fallback ~= nil then
			table.insert(found, fallback)
		end
	end

	table.sort(found, function(a: Types.AnyPart, b: Types.AnyPart): boolean
		if a.price == b.price then
			return a.id < b.id
		end
		return a.price < b.price
	end)

	return found
end

local function caseFits(case: Types.Case, formFactor: Types.FormFactor, gpu: Types.GPU?): boolean
	local supportsBoard = false
	for _, supported in case.supportedFormFactors do
		if supported == formFactor then
			supportsBoard = true
			break
		end
	end
	if not supportsBoard then
		return false
	end
	return gpu == nil or case.maxGpuLengthMM >= gpu.lengthMM
end

--[[
	ประกอบชุดที่ถูกที่สุดที่ตอบ spec ได้ โดยกำหนดการ์ดจอมาให้แล้ว
	(gpu = nil แปลว่าตั้งใจไม่ใส่การ์ดแยก ซีพียูจึงต้องมี iGPU)

	CPU + RAM + Mainboard ต้องเลือกพร้อมกัน เพราะผูกกันด้วย socket และ ramType
	เลือกทีละอย่างแบบ "ถูกที่สุด" จะเจอทางตัน เช่นได้ซีพียู AM5 คู่กับแรม DDR4
]]
local function solveWithGpu(spec: Types.SpecProfile, margin: number, gpu: Types.GPU?): ReferenceBuild?
	local storageList = cheapestFirst("Storage", spec.Storage, margin)
	local storage = storageList[1] :: Types.Storage?
	if storage == nil then
		return nil
	end

	local cpuList = cheapestFirst("CPU", spec.CPU, margin)
	local ramList = cheapestFirst("RAM", spec.RAM, margin)

	local bestCpu: Types.CPU? = nil
	local bestRam: Types.RAM? = nil
	local bestBoard: Types.Mainboard? = nil
	local bestCore = math.huge

	for _, cpuPart in cpuList do
		local cpu = cpuPart :: Types.CPU
		-- ไม่มีการ์ดจอแยก ซีพียูต้องมีการ์ดจอในตัว ไม่งั้นเครื่องไม่มีภาพ
		if gpu == nil and not cpu.hasIGPU then
			continue
		end

		for _, ramPart in ramList do
			local ram = ramPart :: Types.RAM

			for _, board in Components.Mainboard do
				local compatible = board.socket == cpu.socket
					and board.ramType == ram.ramType
					and board.ramSlots >= ram.sticks
					and board.maxRamGB >= ram.sizeGB

				if compatible then
					local core = cpu.price + ram.price + board.price
					if core < bestCore then
						bestCore = core
						bestCpu, bestRam, bestBoard = cpu, ram, board
					end
				end
			end
		end
	end

	if bestCpu == nil or bestRam == nil or bestBoard == nil then
		return nil
	end

	local cpu, ram, board = bestCpu, bestRam, bestBoard

	local case: Types.Case? = nil
	for _, candidate in Components.Case do
		if caseFits(candidate, board.formFactor, gpu) then
			if case == nil or candidate.price < case.price then
				case = candidate
			end
		end
	end
	if case == nil then
		return nil
	end

	local totalWatt = cpu.watt + board.watt + ram.watt + storage.watt + (if gpu ~= nil then gpu.watt else 0)
	local psu: Types.PSU? = nil
	for _, candidate in Components.PSU do
		if candidate.wattOutput >= totalWatt * PSU_HEADROOM then
			if psu == nil or candidate.price < psu.price then
				psu = candidate
			end
		end
	end
	if psu == nil then
		return nil
	end

	local totalPrice = cpu.price + board.price + ram.price + storage.price + case.price + psu.price
		+ (if gpu ~= nil then gpu.price else 0)

	return {
		CPU = cpu,
		Mainboard = board,
		RAM = ram,
		GPU = gpu,
		Storage = storage,
		PSU = psu,
		Case = case,
		totalPrice = totalPrice,
	}
end

--[[
	หาชุดอ้างอิงของโจทย์ 1 ใบ: ชุดที่ถูกที่สุดที่ยังตอบ targetSpec ได้ครบและเข้ากันได้จริง

	ใช้ 2 ที่:
	1. RequestGenerator — เอา totalPrice ไปคิดช่วงงบ (แทนสูตรประมาณเดิม)
	2. RequestDialogue — เอาชื่อชิ้นส่วนไปให้ลูกค้าพูดในโจทย์ระดับ Easy
	ใช้ตัวเดียวกันทั้งคู่ ลูกค้าจึงขอของที่งบของตัวเองซื้อไหวเสมอ

	คืน nil เมื่อประกอบไม่ได้จริง ๆ ผู้เรียกต้องเตรียมทางสำรองไว้
]]
function CatalogInspector.findReferenceBuild(spec: Types.SpecProfile, tolerance: number?): ReferenceBuild?
	local margin = tolerance or DEFAULT_TOLERANCE

	-- ขอการ์ดจอต่ำกว่าเพดาน iGPU = ลองแบบไม่ใส่การ์ดแยกก่อน จะได้ชุดที่ถูกกว่า
	if spec.GPU <= igpuMaxTarget then
		local integrated = solveWithGpu(spec, margin, nil)
		if integrated ~= nil then
			return integrated
		end
		-- ตกมาตรงนี้แปลว่าไม่มีซีพียูที่มี iGPU อยู่ในเกณฑ์เลย ต้องซื้อการ์ดถูกสุดมาใส่แทน
		local cheapest = CatalogInspector.findClosest("GPU", 0) :: Types.GPU?
		return solveWithGpu(spec, margin, cheapest)
	end

	local gpuList = cheapestFirst("GPU", spec.GPU, margin)
	local gpu = gpuList[1] :: Types.GPU?
	if gpu == nil then
		return nil
	end

	return solveWithGpu(spec, margin, gpu)
end

return table.freeze(CatalogInspector)
