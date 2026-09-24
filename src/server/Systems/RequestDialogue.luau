--!strict
-- RequestDialogue.luau — สร้างประโยคที่ลูกค้าพูดจากโจทย์ 1 ราย
-- ไม่ fix ประโยคตายตัว แต่สุ่มประกอบจากคลังคำย่อย เพื่อให้ผู้เล่นเจอข้อความไม่ซ้ำ
-- โครงสร้าง: {ทักทาย} {เกริ่นความต้องการ} {รายละเอียดตามระดับ} {การ์ดจอออนบอร์ด (บางโจทย์)} {ประโยคเรื่องงบ}
-- buildSections คืนแยกเป็นท่อนให้ dialogue GUI แสดงทีละท่อน ส่วน build คืนเป็นข้อความเดียว
-- ตัวบทเป็นภาษาอังกฤษ ส่วนคอมเมนต์อธิบายเป็นภาษาไทย

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local CatalogInspector = require(ReplicatedStorage.Shared.Data.CatalogInspector)

type Difficulty = Types.Difficulty
type UseCase = Types.UseCase

-- คลังคำ: คำทักทายเปิดบทสนทนา (ใช้ได้กับทุกระดับความยาก)
local Greetings: { string } = table.freeze({
	"Hi there!",
	"Hello!",
	"Excuse me, do you have a minute?",
	"Hey, good to see you!",
	"Sorry to bother you!",
	"Pardon me, are you available to help?",
	"Hey, good to see you!",
	"Yo! Are you the one building the PCs?",
	"What's up!",
	"Hey man, got a quick question for you.",
})

-- คลังคำ: ประโยคเกริ่นว่ามาหาคอมพิวเตอร์
local Intents: { string } = table.freeze({
	"I'm looking to buy a PC.",
	"I think it's time for an upgrade.",
	"I want to build a new rig.",
	"I've been meaning to get a desktop for a while now.",
	"I'm ready to build an absolute beast of a PC.",
	"Hey, I'm looking for a new setup.",
	"Hey, I'm looking for a new setup.",
	"I need a computer, but I honestly have no idea where to start.",
	"My friend told me to come here for a new computer.",
})

-- คลังคำ: ประโยคบอกงบ ตัวแปร {min} {max} คือช่วงงบที่จัดรูปแล้ว
local BudgetPhrases: { string } = table.freeze({
	"My budget is about {min} to {max} baht.",
	"I can spend somewhere between {min} and {max} baht.",
	"Let's keep it in the {min} to {max} baht range.",
	"I've got roughly {min} to {max} baht set aside.",
	"Anything from {min} up to {max} baht works for me.",
	"I'd like to stay within the {min} to {max} baht mark.",
	"I've got around {min} to {max} baht to drop on this.",
	"Looking at {min} to {max} baht for the whole setup.",
	"I'd say {min} to {max} baht is what I'm willing to spend.",
	"I can start at {min} baht, but absolutely no more than {max} baht.",
	"Please keep the total between {min} and {max} baht.",
})

--[[
	คลังคำ: รายละเอียดความต้องการ แยกตามระดับความยาก
	- Easy   : บอกเป็นชิ้นส่วนจริง ({cpu} {gpu} = ชื่อรุ่น, {ram} {storage} = ความจุ)
	           ไม่ใช่ตัวเลข perfScore เพราะ perfScore เป็นหน่วยภายในของเกม ลูกค้าไม่พูดแบบนั้น
	- Normal : บอกแค่ชื่อซอฟต์แวร์ ({software}) ผู้เล่นต้องไปเปิดตารางสเปกเอง
	- Hard   : บอกแค่ลักษณะการใช้งานกว้าง ๆ ({useCase}) ต้องเดาซอฟต์แวร์เอง
]]
local DetailTemplates: { [Difficulty]: { string } } = table.freeze({
	Easy = table.freeze({
		"Here's my checklist: {cpu} for the processor, {gpu} for graphics, {ram} of memory, and a {storage} for storage.",
		"My notes say {cpu}, {gpu}, {ram} of RAM, and a {storage} — can you match that?",
		"A friend wrote it all down for me: {cpu}, {gpu}, {ram} of RAM, and a {storage}.",
		"I'm after {cpu} paired with {gpu}, {ram} of memory, and a {storage}.",
		"Make sure it has {cpu}, {gpu}, {ram} of RAM, and a {storage}.",
		"Just give me a build with {cpu}, {gpu}, {ram} of RAM, and a {storage}.",
	}),

	Normal = table.freeze({
		"I mainly want to run {software} smoothly.",
		"It has to handle {software} without stuttering.",
		"I'll be using it for {software}, so please size it for that.",
		"As long as {software} runs nicely, I'll be happy.",
		"The main goal is to get {software} running flawlessly.",
		"If it can run {software} at a decent frame rate, we're good.",
		"I do a lot of work in {software}, so build it around that requirement.",
		"Make sure it meets the recommended specs for {software}.",
			
	}),

	Hard = table.freeze({
		"Mostly I just want something for {useCase}.",
		"It's for {useCase}, nothing too fancy.",
		"I'll be using it for {useCase} most of the time.",
		"Honestly, {useCase} is all I care about — you know better than me what that needs.",
		"I don't know much about parts, just make sure it's good for {useCase}.",
		"Whatever works best for {useCase} is exactly what I want.",
		"Can you build me a solid rig optimized for {useCase}?",
	}),
})

--[[
	คลังคำ: คำบรรยาย useCase แบบภาษาคน ใช้เติมช่อง {useCase} ของระดับ Hard
	มีหลายแบบต่อ 1 useCase เพื่อไม่ให้โจทย์ระดับเดียวกันอ่านเหมือนกันทุกครั้ง
]]
local UseCaseDescriptions: { [UseCase]: { string } } = table.freeze({
	gaming = table.freeze({
		"gaming",
		"playing games with my friends",
		"some serious gaming",
		"PC games, mostly the new ones",
		"playing the latest AAA titles",
		"chilling and playing games after work",
		"running intense gaming sessions",
		"competitive gaming and esports",
		"grinding out some heavy PC games",
	}),

	editing = table.freeze({
		"video editing",
		"editing the clips I shoot",
		"photo and video work",
		"putting videos together for my channel",
		"grinding out some heavy PC games",
		"color grading and 4K video editing",
		"creative workloads like Photoshop and Premiere",
		"rendering out massive project files",
		"digital art and video production",
	}),

	office = table.freeze({
		"office work",
		"documents and spreadsheets",
		"working from home — mail, docs, meetings",
		"everyday paperwork",
		"basic productivity tasks",
		"handling tons of emails and heavy Excel sheets",
		"daily remote work and Zoom calls",
		"general web browsing and word processing",
		"light administrative work",
	}),

	streaming = table.freeze({
		"streaming",
		"streaming my gameplay online",
		"going live for my viewers",
		"streaming and gaming at the same time",
		"broadcasting my gameplay to Twitch",
		"running a high-quality live broadcast",
		"live streaming and chatting with my audience",
		"pushing a smooth stream without dropping frames",
		"VTubing and interacting with my chat",
	}),
})

--[[
	คลังคำ: เทมเพลตระดับ Easy แบบไม่มีการ์ดจอแยก (ใช้ตอนชุดอ้างอิงใช้การ์ดจอออนบอร์ด)
	แยกลิสต์ออกมาเลยแทนที่จะยัดคำว่า "onboard graphics" ลงช่อง {gpu}
	เพราะประโยคอย่าง "onboard graphics for graphics" อ่านแล้วแปลก
]]
local EasyIntegratedTemplates: { string } = table.freeze({
	"Here's my checklist: {cpu} for the processor, {ram} of memory, and a {storage} for storage.",
	"My notes say {cpu}, {ram} of RAM, and a {storage} — can you match that?",
	"A friend wrote it all down for me: {cpu}, {ram} of RAM, and a {storage}.",
	"I'm after {cpu} with {ram} of memory and a {storage}.",
	"Make sure it has {cpu}, {ram} of RAM, and a {storage}.",
	"Just give me a build with {cpu}, {ram} of RAM, and a {storage}.",
})

-- คลังคำ: ประโยคเสริมของระดับ Easy ตอนใช้การ์ดจอออนบอร์ด
local IntegratedGpuNotes: { string } = table.freeze({
	"Integrated graphics is fine, no separate card needed.",
	"I don't need a dedicated graphics card at all.",
	"Onboard graphics will do, so skip the graphics card.",
})

local RequestDialogue = {}

-- สุ่มหยิบ 1 ตัวจากคลังคำ ใช้ rng ที่รับเข้ามาเท่านั้น (ห้าม math.random เพื่อให้ทำซ้ำได้)
local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- แทนที่ช่อง {key} ในเทมเพลตด้วยค่าที่ให้มา ถ้าไม่มีค่าให้คงข้อความเดิมไว้ (จะได้เห็นตอนดีบัก)
local function fill(template: string, values: { [string]: string }): string
	local text = string.gsub(template, "{(%w+)}", function(key: string): string
		return values[key] or "{" .. key .. "}"
	end)
	return text
end

-- จัดรูปจำนวนเงิน: ปัดเป็นจำนวนเต็มแล้วคั่นหลักพันด้วยคอมมา เช่น 24500 → "24,500"
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

-- จัดรูปความจุแบบที่คนพูด: 480 → "480GB", 1000 → "1TB", 4000 → "4TB"
local function formatCapacity(sizeGB: number): string
	if sizeGB >= 1000 and sizeGB % 1000 == 0 then
		return string.format("%dTB", sizeGB // 1000)
	end
	return string.format("%dGB", sizeGB)
end

-- คำเรียกที่เก็บข้อมูลตามชนิด ลูกค้าพูดว่า "1TB SSD" ไม่ใช่ชื่อรุ่นยาว ๆ
local function describeStorage(storage: Types.Storage): string
	if storage.storageKind == "HDD" then
		return formatCapacity(storage.sizeGB) .. " hard drive"
	elseif storage.storageKind == "SATA_SSD" then
		return formatCapacity(storage.sizeGB) .. " SSD"
	end
	return formatCapacity(storage.sizeGB) .. " NVMe SSD"
end

--[[
	ประโยครายละเอียดของระดับ Easy — พูดถึง "ของ" ไม่ใช่ตัวเลข perfScore

	ดึงชิ้นส่วนมาจากชุดอ้างอิงตัวเดียวกับที่ RequestGenerator ใช้คิดงบ
	ลูกค้าจึงขอของที่งบของตัวเองซื้อไหวเสมอ ไม่มีทางขอเกินงบที่ตัวเองให้มา
	ซีพียู/การ์ดจอเรียกด้วยชื่อรุ่น ส่วนแรม/ที่เก็บข้อมูลเรียกด้วยความจุ ตามที่คนพูดกันจริง
	คืน (ประโยครายละเอียด, ประโยคการ์ดจอออนบอร์ด) — ตัวที่สองเป็น nil ถ้ามีการ์ดจอแยก
]]
local function buildEasyDetail(request: Types.CustomerRequest, rng: Random): (string, string?)
	local build = CatalogInspector.findReferenceBuild(request.targetSpec)

	if build == nil then
		-- กันเหนียว: ถ้าประกอบชุดอ้างอิงไม่ได้จริง ๆ อย่างน้อยอย่าให้ประโยคพัง
		return "I am not really sure what parts I need — just put together something that works.", nil
	end

	-- ชุดอ้างอิงไม่มีการ์ดจอแยก = ใช้ออนบอร์ดพอ ใช้เทมเพลตคนละชุดที่ไม่พูดถึงการ์ดจอ
	if build.GPU == nil then
		local detail = fill(pick(EasyIntegratedTemplates, rng), {
			cpu = build.CPU.name,
			ram = formatCapacity(build.RAM.sizeGB),
			storage = describeStorage(build.Storage),
		})
		return detail, pick(IntegratedGpuNotes, rng)
	end

	local detail = fill(pick(DetailTemplates.Easy, rng), {
		cpu = build.CPU.name,
		gpu = build.GPU.name,
		ram = formatCapacity(build.RAM.sizeGB),
		storage = describeStorage(build.Storage),
	})
	return detail, nil
end

-- เลือกและเติมประโยครายละเอียดตามระดับความยากของโจทย์ (ตัวที่สอง = ประโยคการ์ดจอออนบอร์ด ถ้ามี)
local function buildDetail(request: Types.CustomerRequest, rng: Random): (string, string?)
	if request.difficulty == "Easy" then
		return buildEasyDetail(request, rng)
	end

	local template = pick(DetailTemplates[request.difficulty], rng)

	if request.difficulty == "Normal" then
		return fill(template, { software = request.softwareName }), nil
	end

	-- Hard: เหลือแค่คำบรรยายการใช้งานกว้าง ๆ ไม่บอกทั้งชื่อของและชื่อซอฟต์แวร์
	return fill(template, { useCase = pick(UseCaseDescriptions[request.useCase], rng) }), nil
end

--[[
	ประกอบข้อความที่ลูกค้าพูดจากโจทย์ 1 ราย แยกเป็นท่อนตามลำดับที่ dialogue GUI แสดง
		Greetings → Intents → Details → (IntegratedGpuNote ถ้าใช้การ์ดจอออนบอร์ด) → BudgetPhrases
	rng ตัวเดียวกัน + โจทย์เดียวกัน จะได้ข้อความเดิมเสมอ (deterministic)
	หมายเหตุ: ตัวเลข targetSpec ถูกเปิดเผยผ่านข้อความเฉพาะระดับ Easy เท่านั้น
]]
function RequestDialogue.buildSections(request: Types.CustomerRequest, rng: Random): { string }
	-- ลำดับการเรียก rng ต้องคงเดิม (ทักทาย → เกริ่น → รายละเอียด → งบ) seed เดิมจะได้ข้อความเดิม
	local sections = { pick(Greetings, rng), pick(Intents, rng) }

	local detail, integratedGpuNote = buildDetail(request, rng)
	table.insert(sections, detail)
	if integratedGpuNote ~= nil then
		table.insert(sections, integratedGpuNote)
	end

	table.insert(sections, fill(pick(BudgetPhrases, rng), {
		min = formatMoney(request.budgetMin),
		max = formatMoney(request.budgetMax),
	}))
	return sections
end

-- ข้อความทั้งหมดต่อกันเป็นประโยคเดียว (ใช้กับ CustomerRequestPublic.dialogue และ DevTest)
function RequestDialogue.build(request: Types.CustomerRequest, rng: Random): string
	return table.concat(RequestDialogue.buildSections(request, rng), " ")
end

return table.freeze(RequestDialogue)
