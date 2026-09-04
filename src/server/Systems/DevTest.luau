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
	4. ตรวจ coverage ของหมวดใน SpecProfile (CPU/GPU/RAM/Storage) ช่วง target 10-90
	5. ตรวจว่า id ไม่ซ้ำกันทั้ง 7 หมวด
	6. ตรวจว่า perfScore ของทุกชิ้นอยู่ในช่วงของ tier ตัวเอง
	7. ตรวจว่าทุก socket ประกอบ CPU + Mainboard + RAM + Case ได้จริงอย่างน้อย 1 ชุด
	8. สุ่มโจทย์ 30 ราย แล้วรายงาน % ที่หาชิ้นส่วนได้ครบ + หมวดที่เป็นคอขวด
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Enums = require(Shared.Data.Enums)
local SoftwareRequirements = require(Shared.Data.SoftwareRequirements)

local RequestGenerator = require(script.Parent.RequestGenerator)
local RequestDialogue = require(script.Parent.RequestDialogue)
local Components = require(Shared.Data.Components)
local CatalogInspector = require(Shared.Data.CatalogInspector)

local DEFAULT_SEED = 20260901
local REQUESTS_PER_DIFFICULTY = 3
local WEIGHT_TOLERANCE = 0.001 -- น้ำหนักรวมกันคลาดเคลื่อนได้เท่านี้ (float ปัดเศษ)
local SPEC_KEYS: { string } = table.freeze({ "CPU", "GPU", "RAM", "Storage" })

-- ช่วง target ที่ใช้ตรวจ coverage ของแคตตาล็อก (เทส 4)
local COVERAGE_FROM = 10
local COVERAGE_TO = 90
local COVERAGE_STEP = 5

-- เทส 8: สุ่มโจทย์ระดับละกี่ราย และเกณฑ์ % ที่ยอมรับได้
local REQUESTS_PER_DIFFICULTY_SOLVABILITY = 10
local SOLVABLE_TARGET_PERCENT = 90

-- ทำ index ของซอฟต์แวร์ไว้ล่วงหน้า จะได้เทียบ targetSpec กับ min/recommended ได้เร็ว
local softwareById: { [string]: Types.SoftwareRequirement } = {}
for _, software in SoftwareRequirements do
	softwareById[software.id] = software
end

local DevTest = {}

-- นับปัญหาของการรันรอบปัจจุบัน รีเซ็ตทุกครั้งที่เรียก run()
local issueCount = 0

-- warn ปัญหาที่ไม่ได้ผูกกับโจทย์ใบไหน (ใช้กับเทสแคตตาล็อก ข้อ 4-8)
local function fail(message: string)
	issueCount += 1
	warn(string.format("[DevTest] %s", message))
end

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
	2.5 ตัวเลข targetSpec ห้ามโผล่ในข้อความของทุกระดับ (เฉลยต้องไม่รั่ว)

	เดิมเทสนี้ข้ามระดับ Easy ทั้งระดับ เพราะตอนนั้น Easy บอก perfScore ตรง ๆ
	ตอนนี้ Easy เปลี่ยนไปพูดถึงชิ้นส่วนจริงแล้ว จึงต้องตรวจด้วยว่าไม่มีเลขดิบหลุดมา

	ตัดข้อความที่เปิดเผยได้ออกก่อนแล้วค่อยไล่หาเลขที่เหลือ:
	- ช่วงงบ                      : ทุกระดับ
	- ชื่อชิ้นส่วน + ความจุ        : ระดับ Easy (ชื่อรุ่นมีเลขปน เช่น "G7400" ไม่ใช่การรั่ว)
	- ชื่อซอฟต์แวร์               : ระดับ Normal (เช่น "ManualCAD 2025")
]]
local function checkDialogueLeak(request: Types.CustomerRequest, dialogue: string)
	local haystack = string.gsub(dialogue, escapePattern(formatMoney(request.budgetMin)), " ")
	haystack = string.gsub(haystack, escapePattern(formatMoney(request.budgetMax)), " ")

	if request.difficulty == "Easy" then
		local build = CatalogInspector.findReferenceBuild(request.targetSpec)
		if build == nil then
			report(request, "หาชุดอ้างอิงไม่ได้ ประโยคระดับ Easy จะตกไปใช้ข้อความสำรอง")
			return
		end

		haystack = string.gsub(haystack, escapePattern(build.CPU.name), " ")
		if build.GPU ~= nil then
			haystack = string.gsub(haystack, escapePattern(build.GPU.name), " ")
		end
		-- ความจุที่ลูกค้าพูด เช่น "16GB" "2TB" ตัดออกด้วย ไม่งั้นจะถูกนับเป็นเลขที่รั่ว
		haystack = string.gsub(haystack, "%d+%s*[GT]B", " ")
	elseif request.difficulty == "Normal" then
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
	เทส 4 — ทุกหมวดที่อยู่ใน SpecProfile ต้องมีของขายครอบคลุมช่วง target 10-90 (ทีละ 5)
	ถ้ามีช่วงว่าง แปลว่าโจทย์ที่สุ่มมาตกใส่ช่วงนั้นจะหาชิ้นส่วนมาตอบไม่ได้เลย
]]
local function testSpecCoverage()
	print("[DevTest] --- 4. coverage ของหมวดใน SpecProfile ---")

	local tolerancePercent = math.floor(CatalogInspector.DEFAULT_TOLERANCE * 100 + 0.5)
	for _, category in CatalogInspector.SPEC_CATEGORIES do
		local gaps = CatalogInspector.findCoverageGaps(category, COVERAGE_FROM, COVERAGE_TO, COVERAGE_STEP)

		if #gaps == 0 then
			print(string.format("[DevTest]   ✔ %s ครอบคลุมครบ target %d-%d",
				category, COVERAGE_FROM, COVERAGE_TO))
		else
			local labels: { string } = {}
			for _, target in gaps do
				table.insert(labels, tostring(target))
			end
			fail(string.format("%s ไม่มีชิ้นส่วนรองรับ target: %s (เกณฑ์ ±%d%%)",
				category, table.concat(labels, ", "), tolerancePercent))
		end
	end
end

--[[
	เทส 5 — id ห้ามซ้ำกันข้ามทั้ง 7 หมวด
	หมายเหตุ: Components/init.luau assert เรื่องนี้ไว้ตั้งแต่ตอนโหลด module แล้ว
	(ถ้า id ซ้ำจริง เกมจะ error ก่อนมาถึงบรรทัดนี้) เทสนี้เป็นตาข่ายชั้นที่สอง
	เผื่อวันหลังมีคนถอด assert ออกไป
]]
local function testUniqueIds()
	print("[DevTest] --- 5. id ไม่ซ้ำทั้ง 7 หมวด ---")

	local seen: { [string]: Types.Category } = {}
	local duplicates = 0
	local total = 0

	for _, part in Components.getAll() do
		total += 1
		local previous = seen[part.id]
		if previous ~= nil then
			duplicates += 1
			fail(string.format('id ซ้ำ "%s" (อยู่ทั้งในหมวด %s และ %s)', part.id, previous, part.category))
		else
			seen[part.id] = part.category
		end
	end

	if duplicates == 0 then
		print(string.format("[DevTest]   ✔ id ไม่ซ้ำเลย ตรวจแล้ว %d ชิ้น", total))
	end
end

-- ช่วง perfScore ที่ tier หนึ่ง ๆ ต้องอยู่: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100
local function tierRange(tier: number): (number, number)
	if tier == 1 then
		return 0, 20
	end
	return (tier - 1) * 20 + 1, tier * 20
end

-- เทส 6 — perfScore ของทุกชิ้นต้องอยู่ในช่วงของ tier ตัวเอง
local function testTierRanges()
	print("[DevTest] --- 6. perfScore สอดคล้องกับ tier ---")

	local bad = 0
	local total = 0

	for _, part in Components.getAll() do
		total += 1

		if part.tier < Enums.MIN_TIER or part.tier > Enums.MAX_TIER then
			bad += 1
			fail(string.format('%s ("%s") tier = %d หลุดช่วง %d-%d',
				part.id, part.name, part.tier, Enums.MIN_TIER, Enums.MAX_TIER))
		else
			local low, high = tierRange(part.tier)
			if part.perfScore < low or part.perfScore > high then
				bad += 1
				fail(string.format('%s ("%s") tier %d ต้องมี perfScore %d-%d แต่เป็น %d',
					part.id, part.name, part.tier, low, high, part.perfScore))
			end
		end
	end

	if bad == 0 then
		print(string.format("[DevTest]   ✔ perfScore ตรงช่วง tier ครบ %d ชิ้น", total))
	end
end

-- เคสใส่เมนบอร์ดขนาดนี้ได้ไหม
local function caseSupports(case: Types.Case, formFactor: Types.FormFactor): boolean
	for _, supported in case.supportedFormFactors do
		if supported == formFactor then
			return true
		end
	end
	return false
end

--[[
	เทส 7 — ทุก socket ที่มีซีพียูขาย ต้องประกอบชุด CPU + Mainboard + RAM + Case
	ที่เข้ากันได้ครบได้อย่างน้อย 1 ชุด ไม่งั้นซีพียู socket นั้นคือของตายในร้าน
	(ยังไม่รวม GPU/PSU/Storage เพราะสามหมวดนั้นไม่ผูกกับ socket)
]]
local function testBuildablePerSocket()
	print("[DevTest] --- 7. มีชุดที่ประกอบได้จริงทุก socket ---")

	-- เก็บ socket ตามลำดับที่เจอในแคตตาล็อก ผลจะได้เรียงเหมือนเดิมทุกรอบ
	local sockets: { Types.Socket } = {}
	local seenSocket: { [string]: boolean } = {}
	for _, cpu in Components.CPU do
		if not seenSocket[cpu.socket] then
			seenSocket[cpu.socket] = true
			table.insert(sockets, cpu.socket)
		end
	end

	for _, socket in sockets do
		local example: string? = nil

		for _, cpu in Components.CPU do
			if cpu.socket ~= socket then
				continue
			end
			for _, board in Components.Mainboard do
				-- socket ต้องตรง ไม่งั้นเสียบซีพียูไม่ลง
				if board.socket ~= socket then
					continue
				end
				for _, ram in Components.RAM do
					-- ชนิดแรมต้องตรง จำนวนแถวต้องไม่เกินสล็อต และความจุต้องไม่เกินที่บอร์ดรับได้
					if ram.ramType ~= board.ramType or ram.sticks > board.ramSlots or ram.sizeGB > board.maxRamGB then
						continue
					end
					for _, case in Components.Case do
						if caseSupports(case, board.formFactor) then
							example = string.format("%s + %s + %s + %s", cpu.name, board.name, ram.name, case.name)
							break
						end
					end
					if example ~= nil then
						break
					end
				end
				if example ~= nil then
					break
				end
			end
			if example ~= nil then
				break
			end
		end

		if example ~= nil then
			print(string.format("[DevTest]   ✔ %s: %s", socket, example))
		else
			fail(string.format("socket %s ไม่มีชุด CPU + Mainboard + RAM + Case ที่เข้ากันได้เลย", socket))
		end
	end
end

--[[
	เทส 8 — สุ่มโจทย์ระดับละ REQUESTS_PER_DIFFICULTY_SOLVABILITY ราย
	แล้วถาม CatalogInspector ว่าแต่ละใบมีชิ้นส่วนรองรับครบทั้ง 4 หมวดไหม
	รายงานเป็น % และถ้าต่ำกว่าเกณฑ์ ให้บอกด้วยว่าหมวดไหนเป็นคอขวด
]]
local function testRequestSolvability(seed: number)
	local perDifficulty = REQUESTS_PER_DIFFICULTY_SOLVABILITY
	local expected = perDifficulty * #Enums.DifficultyList
	print(string.format("[DevTest] --- 8. โจทย์ที่แก้ได้ครบทุกหมวด (%d ราย/ระดับ รวม %d ราย) ---",
		perDifficulty, expected))

	local rng = Random.new(seed)
	local total = 0
	local solvable = 0
	local missCount: { [string]: number } = {}
	local missExample: { [string]: string } = {}

	for _, difficulty in Enums.DifficultyList do
		for _ = 1, perDifficulty do
			local request = RequestGenerator.generate(difficulty, rng)
			local coverage = CatalogInspector.checkSpec(request.targetSpec)
			total += 1

			if coverage.ok then
				solvable += 1
			else
				for _, category in coverage.missing do
					missCount[category] = (missCount[category] or 0) + 1
					-- เก็บตัวอย่างใบแรกของแต่ละหมวดไว้ จะได้เห็นว่าตันเพราะเลขอะไร
					if missExample[category] == nil then
						missExample[category] = string.format('%s (%s / "%s") ขอ %s = %d',
							request.id, request.difficulty, request.softwareName,
							category, specValue(request.targetSpec, category))
					end
				end
			end
		end
	end

	local percent = if total > 0 then solvable / total * 100 else 0
	print(string.format("[DevTest]   แก้ได้ครบ %d/%d ราย = %.1f%%", solvable, total, percent))

	if percent >= SOLVABLE_TARGET_PERCENT then
		print(string.format("[DevTest]   ✔ ผ่านเกณฑ์ %d%%", SOLVABLE_TARGET_PERCENT))
		return
	end

	fail(string.format("โจทย์ที่แก้ได้ครบมีแค่ %.1f%% ต่ำกว่าเกณฑ์ %d%% — หมวดที่เป็นคอขวด:",
		percent, SOLVABLE_TARGET_PERCENT))

	-- เรียงหมวดที่ตันบ่อยสุดขึ้นก่อน ถ้าเท่ากันใช้ชื่อหมวดตัดสิน ผลจะได้เหมือนเดิมทุกรอบ
	local ranked: { string } = {}
	for category in missCount do
		table.insert(ranked, category)
	end
	table.sort(ranked, function(a: string, b: string): boolean
		if missCount[a] == missCount[b] then
			return a < b
		end
		return missCount[a] > missCount[b]
	end)

	for _, category in ranked do
		warn(string.format("[DevTest]     %s ตัน %d/%d ราย (%.1f%%) เช่น %s",
			category, missCount[category], total, missCount[category] / total * 100, missExample[category]))
	end
end

--[[
	รันเทสทั้งชุด ผลออกที่หน้าต่าง Output
	คืนค่า true เมื่อไม่พบปัญหาเลย (เอาไปเช็คต่อใน command bar ได้)
]]
function DevTest.run(seed: number?): boolean
	local activeSeed = seed or DEFAULT_SEED
	issueCount = 0

	print(string.format("[DevTest] เริ่มเทสระบบสุ่มโจทย์ (seed = %d, %d ราย/ระดับ)", activeSeed, REQUESTS_PER_DIFFICULTY))

	-- เทสแคตตาล็อก (ข้อ 4-7 ไม่ขึ้นกับ seed, ข้อ 8 ใช้ seed แยกจากชุดสุ่มโจทย์ด้านล่าง)
	testSpecCoverage()
	testUniqueIds()
	testTierRanges()
	testBuildablePerSocket()
	testRequestSolvability(activeSeed + 2)

	print("[DevTest] --- 1-3. ระบบสุ่มโจทย์ + determinism ---")
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
