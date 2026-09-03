--!strict
--[[
	⚠️ DevTest.luau — โมดูลทดสอบชั่วคราวสำหรับ dev ลบออกก่อนส่งงานจริง
	⚠️ พิมพ์ targetSpec (เฉลย) ลง Output ห้ามให้เหลืออยู่ในเกมตอนส่ง

	ไม่รันเอง ต้องสั่งจาก command bar ของ Studio:
		require(game.ServerScriptService.Server.Systems.DevTest).run()
	ระบุ seed เองก็ได้:
		require(game.ServerScriptService.Server.Systems.DevTest).run(12345)
	(Studio cache โมดูลไว้ ถ้าแก้โค้ดแล้วอยากรันใหม่ ให้กด Stop/Play หรือ reconnect Rojo ก่อน)

	สิ่งที่เทส:
	1. สุ่มโจทย์ระดับละ 3 ราย รวม 9 ราย แล้ว debugPrint + ข้อความ dialogue
	2. ตรวจความถูกต้องของโจทย์ แล้ว warn เมื่อเจอปัญหา
	3. รันซ้ำด้วย seed เดิม เทียบว่าผลลัพธ์เหมือนกันเป๊ะ (deterministic)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Enums = require(Shared.Data.Enums)
local SoftwareRequirements = require(Shared.Data.SoftwareRequirements)

-- หมายเหตุ: ยังไม่มีไฟล์ RequestGenerator ในโปรเจค เทสนี้เขียนตามสัญญา API ที่คาดไว้
--   RequestGenerator.generate(difficulty: Difficulty, rng: Random): Types.CustomerRequest
--   RequestGenerator.debugPrint(request: Types.CustomerRequest)
local RequestGenerator = require(script.Parent.RequestGenerator)
local RequestDialogue = require(script.Parent.RequestDialogue)

local DEFAULT_SEED = 20260901
local REQUESTS_PER_DIFFICULTY = 3
local WEIGHT_TOLERANCE = 0.001 -- น้ำหนักรวมกันคลาดเคลื่อนได้เท่านี้ (float ปัดเศษ)
local SPEC_KEYS: { string } = table.freeze({ "CPU", "GPU", "RAM", "Storage" })

-- ทำ index ของซอฟต์แวร์ไว้ล่วงหน้า จะได้เทียบ targetSpec กับ min/recommended ได้เร็ว
local softwareById: { [string]: Types.SoftwareRequirement } = {}
for _, software in SoftwareRequirements do
	softwareById[software.id] = software
end

local DevTest = {}

-- นับปัญหาของการรันรอบปัจจุบัน รีเซ็ตทุกครั้งที่เรียก run()
local issueCount = 0

local function report(request: Types.CustomerRequest, message: string)
	issueCount += 1
	warn(string.format("[DevTest] %s (%s/%s) — %s", request.id, request.difficulty, request.useCase, message))
end

-- SpecProfile มี key คงที่ 4 ตัว แต่ strict mode ไม่ยอมให้ index ด้วยตัวแปร เลยต้อง cast
local function specValue(spec: Types.SpecProfile, key: string): number
	return (spec :: any)[key]
end

-- ปัดเป็นจำนวนเต็ม + คั่นหลักพัน ให้ตรงกับที่ RequestDialogue ใช้ (ไว้ตัดตัวเลขงบออกตอนหาการรั่ว)
local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount + 0.5))
	while true do
		local replaced, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return text
end

-- escape อักขระพิเศษของ Lua pattern เพื่อเอาข้อความไปใช้แบบตรงตัว
local function escapePattern(text: string): string
	local escaped = string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	return escaped
end

-- 2.1 targetSpec ต้องอยู่ในช่วง 0-100 ตามที่ Enums กำหนด
local function checkSpecRange(request: Types.CustomerRequest)
	for _, key in SPEC_KEYS do
		local value = specValue(request.targetSpec, key)
		if value < Enums.MIN_PERF_SCORE or value > Enums.MAX_PERF_SCORE then
			report(request, string.format("targetSpec.%s = %.2f หลุดช่วง %d-%d",
				key, value, Enums.MIN_PERF_SCORE, Enums.MAX_PERF_SCORE))
		end
	end
end

-- 2.2 targetSpec ต้องอยู่ระหว่าง minSpec กับ recommendedSpec ของซอฟต์แวร์ที่อ้างถึง
local function checkSpecBounds(request: Types.CustomerRequest)
	local software = softwareById[request.softwareId]
	if software == nil then
		report(request, string.format('ไม่พบ softwareId "%s" ใน SoftwareRequirements', request.softwareId))
		return
	end

	if software.name ~= request.softwareName then
		report(request, string.format('softwareName "%s" ไม่ตรงกับแคตตาล็อก ("%s")', request.softwareName, software.name))
	end

	for _, key in SPEC_KEYS do
		local value = specValue(request.targetSpec, key)
		local minValue = specValue(software.minSpec, key)
		local maxValue = specValue(software.recommendedSpec, key)

		if value < minValue then
			report(request, string.format("targetSpec.%s = %.2f ต่ำกว่า minSpec (%.2f)", key, value, minValue))
		elseif value > maxValue then
			report(request, string.format("targetSpec.%s = %.2f สูงกว่า recommendedSpec (%.2f)", key, value, maxValue))
		end
	end
end

-- 2.3 ช่วงงบต้องกว้างจริง ไม่งั้นผู้เล่นไม่มีทางเลือก
local function checkBudget(request: Types.CustomerRequest)
	if request.budgetMin >= request.budgetMax then
		report(request, string.format("budgetMin (%.2f) ต้องน้อยกว่า budgetMax (%.2f)", request.budgetMin, request.budgetMax))
	end
end

-- 2.4 น้ำหนักที่ใช้คิด FitScore ต้องรวมกันได้ 1.0
local function checkWeights(request: Types.CustomerRequest)
	local total = 0
	for _, key in SPEC_KEYS do
		total += specValue(request.weights, key)
	end

	if math.abs(total - 1) > WEIGHT_TOLERANCE then
		report(request, string.format("น้ำหนักรวม = %.4f ควรเป็น 1.0 (คลาดเคลื่อนได้ %.3f)", total, WEIGHT_TOLERANCE))
	end
end

--[[
	2.5 ระดับ Normal/Hard ห้ามมีตัวเลข targetSpec โผล่ในข้อความ (เฉลยต้องไม่รั่ว)
	ตัดตัวเลขที่เปิดเผยได้ออกก่อน: ช่วงงบทุกระดับ + ชื่อซอฟต์แวร์ของระดับ Normal
	(ชื่อซอฟต์แวร์บางตัวมีเลขปนอยู่ เช่น "AutoCAD 2025" ไม่ใช่การรั่ว)
]]
local function checkDialogueLeak(request: Types.CustomerRequest, dialogue: string)
	if request.difficulty == "Easy" then
		return -- ระดับ Easy ตั้งใจบอกตัวเลขตรง ๆ อยู่แล้ว
	end

	local haystack = string.gsub(dialogue, escapePattern(formatMoney(request.budgetMin)), " ")
	haystack = string.gsub(haystack, escapePattern(formatMoney(request.budgetMax)), " ")
	if request.difficulty == "Normal" then
		haystack = string.gsub(haystack, escapePattern(request.softwareName), " ")
	end

	local targetTokens: { [string]: string } = {}
	for _, key in SPEC_KEYS do
		targetTokens[tostring(math.floor(specValue(request.targetSpec, key) + 0.5))] = key
	end

	for token in string.gmatch(haystack, "%d+") do
		local leakedKey = targetTokens[token]
		if leakedKey ~= nil then
			report(request, string.format('dialogue หลุดเลข targetSpec.%s (%s) — "%s"', leakedKey, token, dialogue))
		end
	end
end

local function validate(request: Types.CustomerRequest, dialogue: string)
	checkSpecRange(request)
	checkSpecBounds(request)
	checkBudget(request)
	checkWeights(request)
	checkDialogueLeak(request, dialogue)
end

-- ย่อโจทย์ + ข้อความ ให้เป็นบรรทัดเดียว ไว้เทียบผลสองรอบแบบตรงตัว
local function fingerprint(request: Types.CustomerRequest, dialogue: string): string
	return string.format("%s|%s|%s|%s|%.4f/%.4f/%.4f/%.4f|%.4f/%.4f/%.4f/%.4f|%.4f-%.4f|%s",
		request.id,
		request.difficulty,
		request.useCase,
		request.softwareId,
		request.targetSpec.CPU, request.targetSpec.GPU, request.targetSpec.RAM, request.targetSpec.Storage,
		request.weights.CPU, request.weights.GPU, request.weights.RAM, request.weights.Storage,
		request.budgetMin, request.budgetMax,
		dialogue)
end

--[[
	สุ่มโจทย์ครบทุกระดับ ระดับละ REQUESTS_PER_DIFFICULTY ราย
	verbose = true คือรอบแรก (พิมพ์ผล + ตรวจปัญหา) รอบสองเงียบ ใช้แค่เทียบ fingerprint
]]
local function runSuite(seed: number, verbose: boolean): { string }
	local rng = Random.new(seed)
	local dialogueRng = Random.new(seed + 1) -- แยก rng ของข้อความ ไม่ให้ไปกวนลำดับสุ่มของโจทย์
	local fingerprints: { string } = {}

	for _, difficulty in Enums.DifficultyList do
		for _ = 1, REQUESTS_PER_DIFFICULTY do
			local request = RequestGenerator.generate(difficulty, rng)
			local dialogue = RequestDialogue.build(request, dialogueRng)

			if verbose then
				RequestGenerator.debugPrint(request)
				-- พิมพ์ข้อความต่อท้ายเฉลย จะได้เทียบด้วยตาว่าเปิดเผยข้อมูลตรงตามระดับไหม
				print(string.format('  dialogue: "%s"', dialogue))
				print(string.rep("-", 72))
				validate(request, dialogue)
			end

			table.insert(fingerprints, fingerprint(request, dialogue))
		end
	end

	return fingerprints
end

--[[
	รันเทสทั้งชุด ผลออกที่หน้าต่าง Output
	คืนค่า true เมื่อไม่พบปัญหาเลย (เอาไปเช็คต่อใน command bar ได้)
]]
function DevTest.run(seed: number?): boolean
	local activeSeed = seed or DEFAULT_SEED
	issueCount = 0

	print(string.format("[DevTest] เริ่มเทสระบบสุ่มโจทย์ (seed = %d, %d ราย/ระดับ)", activeSeed, REQUESTS_PER_DIFFICULTY))

	local firstRun = runSuite(activeSeed, true)
	local secondRun = runSuite(activeSeed, false)

	-- 3. seed เดิมต้องได้ผลเหมือนเดิมทุกตัวอักษร ถ้าไม่เหมือนแปลว่ามีจุดไหนสุ่มนอก rng
	local isDeterministic = true
	if #firstRun ~= #secondRun then
		isDeterministic = false
		warn(string.format("[DevTest] จำนวนโจทย์สองรอบไม่เท่ากัน (%d vs %d)", #firstRun, #secondRun))
	else
		for index, line in firstRun do
			if line ~= secondRun[index] then
				isDeterministic = false
				warn(string.format("[DevTest] ผลรอบที่ 1 กับ 2 ต่างกันที่รายการ %d", index))
				warn(string.format("[DevTest]   รอบ 1: %s", line))
				warn(string.format("[DevTest]   รอบ 2: %s", secondRun[index]))
				break
			end
		end
	end

	if isDeterministic then
		print(string.format("[DevTest] ✔ seed เดิมให้ผลเหมือนกันครบทั้ง %d ราย", #firstRun))
	else
		issueCount += 1
		warn("[DevTest] ✘ ผลไม่ deterministic — เช็คว่ามีจุดไหนใช้ math.random หรือ tick() ในระบบสุ่มหรือเปล่า")
	end

	if issueCount == 0 then
		print(string.format("[DevTest] ✔ ผ่านครบ %d ราย ไม่พบปัญหา", #firstRun))
		return true
	end

	warn(string.format("[DevTest] ✘ พบปัญหาทั้งหมด %d จุด (ดู warning ด้านบน)", issueCount))
	return false
end

return DevTest
