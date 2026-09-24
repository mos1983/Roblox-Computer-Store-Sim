--!strict
--[[
	NPCService.luau — ลูกค้า NPC: spawn → เดินเข้าเคาน์เตอร์ → dialogue → เดินออก → ลบ
	เกมเป็น singleplayer (server จำกัด 1 คน) ร้านจึงมีลูกค้าได้ทีละคน

	ลำดับ (ค่าเวลาทั้งหมดอยู่ใน NPCConfig)
		client ส่ง Remotes.GameStarted ตอนกด Play → ร้าน Idle → รอ SPAWN_INTERVAL
		→ spawn ที่ Checkpoint1 (Queued) → หัน → เดินไป Checkpoint2_1 → หยุด PAUSE_AT_CP2_1
		→ หัน → เดินไป Checkpoint2_2 → หันตามหน้าของ part → รอ DIALOGUE_DELAY
		→ สุ่มโจทย์ แล้วส่ง DialoguePayload ทาง Remotes.DialogueShow
		→ รอ client ส่ง Remotes.DialogueFinished (กด Continue ท่อนสุดท้าย) → รอ LEAVE_DELAY
		→ หัน → เดินกลับ Checkpoint1 → ลบ model → Idle → วนรอบใหม่

	การเดิน: anchor root part แล้วเลื่อนด้วย PivotTo เป็นเส้นตรงด้วยความเร็วคงที่
	ไม่ใช้ Humanoid:MoveTo เพราะชนกำแพงแล้วติด หมดเวลาเองใน 8 วินาที และความเร็วไม่คงที่
	แบบนี้เดินทะลุกำแพงช่วงที่ผู้เล่นมองไม่เห็นได้ตามเอกสาร และจุดหมุนของ model ตรงกับ checkpoint พอดี
	ยังไม่มีท่าเดิน (R6 ทำทีหลัง) จึงเก็บ Humanoid ไว้ใช้เล่น animation ตอนนั้น

	โจทย์เต็ม (มี targetSpec) เก็บไว้ฝั่ง server เท่านั้น client ได้แค่ DialoguePayload
	instance ทั้งหมดอยู่ใน Studio (รวม RemoteEvent) หาไม่เจอจะ warn path แล้วไม่เริ่มระบบนี้ ระบบอื่นไม่พังตาม
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local NPCTypes = require(ReplicatedStorage.Shared.NPCTypes)
local Enums = require(ReplicatedStorage.Shared.Data.Enums)
local NPCConfig = require(ReplicatedStorage.Shared.Config.NPCConfig)
local RequestGenerator = require(script.Parent.RequestGenerator)
local RequestDialogue = require(script.Parent.RequestDialogue)

type StoreState = NPCTypes.StoreState
type DialoguePayload = NPCTypes.DialoguePayload

-- instance ใน Studio ที่ระบบนี้ต้องใช้ (หาครั้งเดียวตอน init)
type World = {
	templates: { Model }, -- ReplicatedStorage.Model.NPCs สุ่มหยิบมา clone
	spawnParent: Instance, -- Workspace.NPCs.MainNPCs
	checkpoint1: BasePart, -- จุดเกิดและจุดลบ
	checkpoint2_1: BasePart, -- จุดแวะก่อนเข้าเคาน์เตอร์
	checkpoint2_2: BasePart, -- หน้าเคาน์เตอร์ (คุยตรงนี้)
	gameStarted: RemoteEvent,
	dialogueShow: RemoteEvent,
	dialogueFinished: RemoteEvent,
}

type Customer = {
	npcId: string,
	model: Model,
	request: Types.CustomerRequest?, -- เฉลยอยู่ server เท่านั้น เก็บไว้ตรวจเครื่องที่ผู้เล่นประกอบ (ขั้นถัดไป)
	waitingThread: thread?, -- thread ที่รอผู้เล่นกด Continue ท่อนสุดท้าย
}

local FIND_TIMEOUT: number = 10 -- วินาที เผื่อ Workspace ยังโหลดไม่เสร็จ
local NPC_TYPE_CUSTOMER: string = "CUSTOMER"

local NPCService = {}

local initialized: boolean = false
local storeState: StoreState = "Idle"
local storePlayer: Player? = nil -- ผู้เล่นที่กด Play (singleplayer มีคนเดียว)
local current: Customer? = nil
local nextNpcNumber: number = 0

-- seed เดียวต่อ server แยก rng ของข้อความออกมา ไม่ให้ไปกวนลำดับสุ่มของโจทย์ (แบบเดียวกับ DevTest)
local seed: number = os.time()
local rng: Random = Random.new(seed) -- สุ่ม model + ระดับความยาก + โจทย์
local dialogueRng: Random = Random.new(seed + 1)

--[[
	หา instance ตาม path คั่นด้วยจุด แบบเดียวกับ SafeFind ฝั่ง client (ตัวนั้นอยู่ใน StarterPlayerScripts server ใช้ไม่ได้)
	หาไม่เจอหรือชนิดไม่ตรง: warn path เต็มแล้วคืน nil
]]
local function findPath(root: Instance, path: string, className: string): Instance?
	local node = root
	for _, name in string.split(path, ".") do
		local child = node:WaitForChild(name, FIND_TIMEOUT)
		if child == nil then
			warn(`[NPCService] หา {root:GetFullName()}.{path} ไม่เจอ (ไม่มี "{name}" ใน {node:GetFullName()}) ระบบ NPC จะไม่ทำงาน`)
			return nil
		end
		node = child
	end
	if not node:IsA(className) then
		warn(`[NPCService] {node:GetFullName()} เป็น {node.ClassName} ไม่ใช่ {className} ระบบ NPC จะไม่ทำงาน`)
		return nil
	end
	return node
end

-- หา instance ทั้งหมดที่ต้องใช้ ขาดตัวไหนคืน nil (warn บอก path ไปแล้ว)
local function loadWorld(): World?
	local templateFolder = findPath(ReplicatedStorage, "Model.NPCs", "Instance")
	local spawnParent = findPath(workspace, "NPCs.MainNPCs", "Instance")
	local checkpoint1 = findPath(workspace, "NPCs.MainNPCsPath.Checkpoint1", "BasePart")
	local checkpoint2_1 = findPath(workspace, "NPCs.MainNPCsPath.Checkpoint2_1", "BasePart")
	local checkpoint2_2 = findPath(workspace, "NPCs.MainNPCsPath.Checkpoint2_2", "BasePart")
	local gameStarted = findPath(ReplicatedStorage, "Remotes.GameStarted", "RemoteEvent")
	local dialogueShow = findPath(ReplicatedStorage, "Remotes.DialogueShow", "RemoteEvent")
	local dialogueFinished = findPath(ReplicatedStorage, "Remotes.DialogueFinished", "RemoteEvent")
	if
		templateFolder == nil
		or spawnParent == nil
		or checkpoint1 == nil
		or checkpoint2_1 == nil
		or checkpoint2_2 == nil
		or gameStarted == nil
		or dialogueShow == nil
		or dialogueFinished == nil
	then
		return nil
	end

	local templates: { Model } = {}
	for _, child in templateFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	if #templates == 0 then
		warn(`[NPCService] ไม่มี Model ใน {templateFolder:GetFullName()} ระบบ NPC จะไม่ทำงาน`)
		return nil
	end

	return {
		templates = templates,
		spawnParent = spawnParent,
		checkpoint1 = checkpoint1 :: BasePart,
		checkpoint2_1 = checkpoint2_1 :: BasePart,
		checkpoint2_2 = checkpoint2_2 :: BasePart,
		gameStarted = gameStarted :: RemoteEvent,
		dialogueShow = dialogueShow :: RemoteEvent,
		dialogueFinished = dialogueFinished :: RemoteEvent,
	}
end

--[[
	ยึด model ไว้กับที่: anchor แค่ root part ส่วนอื่นติดกันด้วย Motor6D จะนิ่งตามเอง
	ไม่ anchor ทั้งตัว เพราะ animation ขยับได้เฉพาะ part ที่ไม่ anchor (เผื่อใส่ท่าเดินทีหลัง)
]]
local function anchorRoot(model: Model): ()
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.Anchored = true
		return
	end
	warn(`[NPCService] {model.Name} ไม่มี PrimaryPart หรือ HumanoidRootPart จะ anchor ทุก part แทน`)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- หันอยู่กับที่จากทิศปัจจุบันไปทิศ goal ด้วย TURN_SPEED (yield จนหันเสร็จ)
local function turnTo(model: Model, goal: CFrame): ()
	local start = model:GetPivot()
	local goalRotation = goal.Rotation
	local _, angle = (start.Rotation:Inverse() * goalRotation):ToAxisAngle()
	local duration = math.deg(math.abs(angle)) / NPCConfig.TURN_SPEED

	local elapsed = 0
	while elapsed < duration and model.Parent ~= nil do
		elapsed += task.wait()
		local alpha = math.min(elapsed / duration, 1)
		model:PivotTo(start.Rotation:Lerp(goalRotation, alpha) + start.Position)
	end
	if model.Parent ~= nil then
		model:PivotTo(goalRotation + start.Position)
	end
end

-- เดินเป็นเส้นตรงไป target ด้วย WALK_SPEED ทิศที่หันอยู่คงเดิม (yield จนถึง)
local function walkTo(model: Model, target: Vector3): ()
	local start = model:GetPivot()
	local duration = (target - start.Position).Magnitude / NPCConfig.WALK_SPEED

	local elapsed = 0
	while elapsed < duration and model.Parent ~= nil do
		elapsed += task.wait()
		local alpha = math.min(elapsed / duration, 1)
		model:PivotTo(start.Rotation + start.Position:Lerp(target, alpha))
	end
	if model.Parent ~= nil then
		model:PivotTo(start.Rotation + target)
	end
end

-- เดินหนึ่งช่วง: หันไปทาง checkpoint ก่อน (มองแนวราบ ไม่ก้มเงย) แล้วค่อยเดิน
local function walkLeg(model: Model, checkpoint: BasePart): ()
	local from = model:GetPivot().Position
	local target = checkpoint.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if flat.Magnitude > 1e-3 then
		turnTo(model, CFrame.lookAt(Vector3.zero, flat))
	end
	walkTo(model, target)
end

-- clone model แบบสุ่มมาวางที่ Checkpoint1 ตำแหน่งและทิศเดียวกับ part
local function spawnCustomer(world: World): Customer
	nextNpcNumber += 1
	local npcId = string.format("npc_%04d", nextNpcNumber)

	local template = world.templates[rng:NextInteger(1, #world.templates)]
	local model = template:Clone()
	model.Name = npcId
	anchorRoot(model)

	-- Humanoid แสดงชื่อ model ลอยบนหัว ("npc_0001") ปิดไว้
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	model:PivotTo(world.checkpoint1.CFrame)
	model.Parent = world.spawnParent
	return { npcId = npcId, model = model, request = nil, waitingThread = nil }
end

-- ลูกค้า 1 คนตั้งแต่เกิดจนเดินกลับถึง Checkpoint1 (yield ตลอดทาง) การลบ model อยู่ที่ runStore
local function serveCustomer(world: World, player: Player): ()
	local customer = spawnCustomer(world)
	current = customer
	storeState = "Queued"
	local model = customer.model

	walkLeg(model, world.checkpoint2_1)
	task.wait(NPCConfig.PAUSE_AT_CP2_1)
	walkLeg(model, world.checkpoint2_2)
	turnTo(model, world.checkpoint2_2.CFrame)
	task.wait(NPCConfig.DIALOGUE_DELAY)

	local difficulty = Enums.DifficultyList[rng:NextInteger(1, #Enums.DifficultyList)]
	local request = RequestGenerator.generate(difficulty, rng)
	customer.request = request

	local payload: DialoguePayload = {
		npcId = customer.npcId,
		npcType = NPC_TYPE_CUSTOMER,
		info = RequestDialogue.buildSections(request, dialogueRng),
	}
	-- รอผู้เล่นกด Continue ท่อนสุดท้าย: onDialogueFinished จะปลุก thread นี้
	customer.waitingThread = coroutine.running()
	world.dialogueShow:FireClient(player, payload)
	coroutine.yield()

	task.wait(NPCConfig.LEAVE_DELAY)
	walkLeg(model, world.checkpoint1)
end

-- วนรับลูกค้าไปเรื่อยๆ ทีละคน จนผู้เล่นออกจากเกม ลูกค้าคนไหนพังจะ warn แล้วข้ามไปคนถัดไป
local function runStore(world: World, player: Player): ()
	while player.Parent ~= nil do
		task.wait(NPCConfig.SPAWN_INTERVAL)
		if player.Parent == nil then
			break
		end

		local ok, message = pcall(serveCustomer, world, player)
		if not ok then
			warn(`[NPCService] ลูกค้าคนนี้ทำงานไม่สำเร็จ ข้ามไปคนถัดไป: {message}`)
		end

		local customer = current
		current = nil
		if customer ~= nil then
			customer.model:Destroy()
		end
		storeState = "Idle"
	end
end

-- client กด Play: เริ่มรับลูกค้าครั้งเดียวต่อเกม (กดซ้ำหรือส่งซ้ำไม่มีผล)
local function onGameStarted(world: World, player: Player): ()
	if storePlayer ~= nil then
		return
	end
	storePlayer = player
	task.spawn(runStore, world, player)
end

-- client กด Continue ท่อนสุดท้าย: ปลุกลูกค้าที่รออยู่ให้เดินออก (ค่าไม่ตรงกับลูกค้าที่รออยู่ = ไม่ทำอะไร)
local function onDialogueFinished(player: Player, npcId: unknown): ()
	local customer = current
	if player ~= storePlayer or customer == nil or typeof(npcId) ~= "string" or npcId ~= customer.npcId then
		return
	end
	local thread = customer.waitingThread
	if thread == nil then
		return -- ยังไม่ถึงช่วงคุย หรือกดซ้ำหลังปลุกไปแล้ว
	end
	customer.waitingThread = nil
	task.spawn(thread)
end

-- สถานะร้านตอนนี้ (Idle = spawn ลูกค้าใหม่ได้, Queued = มีลูกค้าอยู่)
function NPCService.getStoreState(): StoreState
	return storeState
end

--[[
	เริ่มระบบ เรียกครั้งเดียวจาก init.server.luau (เรียกซ้ำไม่มีผล)
	หา instance ใน background ไม่บล็อกระบบอื่น ครบแล้วค่อยรอ GameStarted จาก client
]]
function NPCService.init(): ()
	if initialized then
		return
	end
	initialized = true

	task.spawn(function(): ()
		local world = loadWorld()
		if world == nil then
			return
		end
		world.gameStarted.OnServerEvent:Connect(function(player: Player): ()
			onGameStarted(world, player)
		end)
		world.dialogueFinished.OnServerEvent:Connect(onDialogueFinished)
	end)
end

return table.freeze(NPCService)
