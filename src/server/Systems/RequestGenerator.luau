--!strict
--[[
	RequestGenerator.luau — สุ่มโจทย์ลูกค้า 1 ราย จากแคตตาล็อกซอฟต์แวร์ + ค่าตั้งใน RequestConfig

	ขั้นตอนการสุ่ม:
	1. สุ่มซอฟต์แวร์ 1 ตัวจาก SoftwareRequirements → ได้ useCase มาด้วย
	2. สุ่ม targetSpec ระหว่าง minSpec กับ recommendedSpec ตามช่วง alpha ของระดับความยาก
	3. ประมาณราคาของสเปกนั้น แล้วคูณช่วงงบตามระดับ → budgetMin / budgetMax
	4. หยิบน้ำหนักของ useCase มาแนบไว้ ใช้ตอนคิด FitScore

	ทุกจุดที่สุ่มใช้ rng ที่รับเข้ามาเท่านั้น (ห้าม math.random) — seed เดิมต้องได้โจทย์เดิมเสมอ
	⚠️ targetSpec ในผลลัพธ์คือเฉลย ห้ามส่งออกไปฝั่ง client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Enums = require(Shared.Data.Enums)
local RequestConfig = require(Shared.Config.RequestConfig)
local SoftwareRequirements = require(Shared.Data.SoftwareRequirements)

type Difficulty = Types.Difficulty

local SPEC_KEYS: { string } = table.freeze({ "CPU", "GPU", "RAM", "Storage" })
local BUDGET_ROUND_TO = 100 -- ปัดงบเป็นหลักร้อย ลูกค้าไม่พูดเลขเศษ

local RequestGenerator = {}

-- SpecProfile มี key คงที่ 4 ตัว แต่ strict mode ไม่ยอมให้ index ด้วยตัวแปร เลยต้อง cast
local function specValue(spec: Types.SpecProfile, key: string): number
	return (spec :: any)[key]
end

local function setSpecValue(spec: Types.SpecProfile, key: string, value: number)
	local mutable: any = spec
	mutable[key] = value
end

--[[
	สุ่มค่าเป้าหมายของแต่ละหมวดระหว่าง minSpec กับ recommendedSpec
	alpha สุ่มแยกรายหมวด (0 = เท่ากับ minSpec, 1 = เท่ากับ recommendedSpec)
	จะได้โจทย์ที่ไม่เอียงไปทางเดียวกันหมดทุกหมวด
]]
local function rollTargetSpec(software: Types.SoftwareRequirement, difficulty: Difficulty, rng: Random): Types.SpecProfile
	local alphaRange = RequestConfig.SpecAlphaRange[difficulty]
	local targetSpec: Types.SpecProfile = { CPU = 0, GPU = 0, RAM = 0, Storage = 0 }

	for _, key in SPEC_KEYS do
		local minValue = specValue(software.minSpec, key)
		local maxValue = specValue(software.recommendedSpec, key)
		local alpha = rng:NextNumber(alphaRange[1], alphaRange[2])
		local value = minValue + (maxValue - minValue) * alpha

		-- ปัดเป็นจำนวนเต็มก่อน แล้วค่อย clamp กันค่าหลุดช่วง 0-100 ถ้าแคตตาล็อกใส่เลขเพี้ยนมา
		local rounded = math.floor(value + 0.5)
		setSpecValue(targetSpec, key, math.clamp(rounded, Enums.MIN_PERF_SCORE, Enums.MAX_PERF_SCORE))
	end

	return targetSpec
end

--[[
	ประมาณราคาเครื่องที่ตรงตาม targetSpec
	TODO: ตอนนี้ใช้สูตรประมาณใน RequestConfig ต้องเปลี่ยนไปคิดจากราคาจริงในแคตตาล็อกเมื่อมีครบ 7 หมวด
]]
local function estimateCost(targetSpec: Types.SpecProfile): number
	local total = RequestConfig.BudgetEstimate.BASE_COST

	for _, key in SPEC_KEYS do
		total += specValue(targetSpec, key) * specValue(RequestConfig.BudgetEstimate.PRICE_PER_POINT, key)
	end

	return total
end

local function roundBudget(amount: number): number
	return math.floor(amount / BUDGET_ROUND_TO + 0.5) * BUDGET_ROUND_TO
end

--[[
	ออก id ของโจทย์จาก rng ไม่ใช้ตัวนับรวมของโมดูล
	เพราะตัวนับจะทำให้รันด้วย seed เดิมสองครั้งได้ id คนละชุด (เทส determinism จะพัง)
]]
local function rollRequestId(rng: Random): string
	return string.format("req_%06d", rng:NextInteger(0, 999999))
end

--[[
	สุ่มโจทย์ลูกค้า 1 ราย ตามระดับความยากที่กำหนด
	rng ตัวเดิม + ลำดับเรียกเดิม จะได้โจทย์เดิมเสมอ
]]
function RequestGenerator.generate(difficulty: Difficulty, rng: Random): Types.CustomerRequest
	local software = SoftwareRequirements[rng:NextInteger(1, #SoftwareRequirements)]
	local targetSpec = rollTargetSpec(software, difficulty, rng)

	local estimated = estimateCost(targetSpec)
	local budgetRange = RequestConfig.BudgetRange[difficulty]

	return {
		id = rollRequestId(rng),
		difficulty = difficulty,
		useCase = software.useCase,
		softwareId = software.id,
		softwareName = software.name,
		targetSpec = targetSpec,
		weights = RequestConfig.UseCaseWeights[software.useCase],
		budgetMin = roundBudget(estimated * budgetRange.min),
		budgetMax = roundBudget(estimated * budgetRange.max),
	}
end

--[[
	พิมพ์เฉลยทั้งใบลง Output — สำหรับ dev เท่านั้น
	⚠️ ห้ามเรียกในโค้ดที่ผู้เล่นมองเห็นผลลัพธ์ได้
]]
function RequestGenerator.debugPrint(request: Types.CustomerRequest)
	print(string.format("[Request] %s | %s | useCase = %s", request.id, request.difficulty, request.useCase))
	print(string.format('  software: %s (%s)', request.softwareName, request.softwareId))
	print(string.format("  targetSpec: CPU %d / GPU %d / RAM %d / Storage %d",
		request.targetSpec.CPU, request.targetSpec.GPU, request.targetSpec.RAM, request.targetSpec.Storage))
	print(string.format("  weights: CPU %.2f / GPU %.2f / RAM %.2f / Storage %.2f",
		request.weights.CPU, request.weights.GPU, request.weights.RAM, request.weights.Storage))
	print(string.format("  budget: %d - %d บาท", request.budgetMin, request.budgetMax))
end

return table.freeze(RequestGenerator)
