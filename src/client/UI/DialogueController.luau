--!strict
--[[
	DialogueController.luau — กล่องคำพูดของ NPC ใน GUI.Main.Dialogue

	server ส่ง DialoguePayload มาทาง Remotes.DialogueShow แล้ว:
	- Dialogue เลื่อนขึ้นจากขอบล่าง ปุ่ม Setting กับ Workshop เลื่อนลงไปหลบ (คุยจบแล้วค่อยกลับมา)
	- Info แสดงข้อความทีละท่อน กด ContinueButton ไปท่อนถัดไป
	- กดท่อนสุดท้าย: ปิดกล่อง แล้วส่ง npcId กลับทาง Remotes.DialogueFinished ให้ NPC เดินออก
	- NpcType แสดง payload.npcType ส่วน Nametag.Name กับ NPCPfp ยังข้ามไว้ก่อน

	Dialogue อยู่ใน Main: ถ้าลูกค้ามาตอนผู้เล่นอยู่หน้า Upgrade/Workshop กล่องจะรออยู่ใน Main ที่ซ่อนอยู่
	แล้วโผล่เองตอนกลับมาหน้าร้าน
	RemoteEvent สร้างไว้ใน Studio (ReplicatedStorage.Remotes) หาไม่เจอจะ warn แล้วระบบนี้ไม่ทำงาน
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafeFind = require(script.Parent.Parent.Util.SafeFind)
local UIAnimator = require(script.Parent.UIAnimator)
local ButtonEffect = require(script.Parent.ButtonEffect)
local NPCTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NPCTypes"))

type DialoguePayload = NPCTypes.DialoguePayload

-- กล่องขึ้นมาจากขอบล่าง ปุ่มลงไปหลบทางขอบล่าง
local DIALOGUE_EDGE: UIAnimator.Edge = "Bottom"
local BUTTON_EDGE: UIAnimator.Edge = "Bottom"
local HIDDEN_BUTTON_NAMES: { string } = { "SettingButton", "WorkshopButton" }

-- ลูกของ Main มาพร้อม Main ถ้าหาไม่เจอแปลว่าชื่อผิด ไม่ต้องรอนาน
local CHILD_TIMEOUT: number = 2

local DialogueController = {}

local initialized: boolean = false
local mainFrame: GuiObject? = nil
local dialogueFrame: GuiObject? = nil
local infoLabel: TextLabel? = nil
local npcTypeLabel: TextLabel? = nil
local hiddenButtons: { GuiObject } = {}
local finishedRemote: RemoteEvent? = nil

local active: DialoguePayload? = nil -- บทสนทนาที่กำลังแสดง (nil = ไม่มีลูกค้าคุยอยู่)
local sectionIndex: number = 0

-- ตรวจรูปแบบของที่ server ส่งมา ไม่ตรงจะ warn แล้วทิ้ง ไม่ให้ GUI พังกลางบทสนทนา
local function parsePayload(value: any): DialoguePayload?
	local valid = typeof(value) == "table"
		and typeof(value.npcId) == "string"
		and typeof(value.npcType) == "string"
		and typeof(value.info) == "table"
		and #value.info > 0
	if valid then
		for _, section in value.info do
			if typeof(section) ~= "string" then
				valid = false
				break
			end
		end
	end
	if not valid then
		warn("[DialogueController] DialoguePayload จาก server รูปแบบไม่ถูกต้อง ข้ามบทสนทนานี้")
		return nil
	end
	return value :: DialoguePayload
end

local function setButtonsShown(shown: boolean): ()
	for _, button in hiddenButtons do
		if shown then
			UIAnimator.slideIn(button, BUTTON_EDGE)
		else
			UIAnimator.slideOut(button, BUTTON_EDGE)
		end
	end
end

local function showSection(payload: DialoguePayload, index: number): ()
	local label = infoLabel
	if label ~= nil then
		label.Text = payload.info[index]
	end
end

-- ลูกค้าเริ่มคุย: แสดงท่อนแรก เลื่อนกล่องขึ้น ปุ่มลงไปหลบ
local function onDialogueShow(value: any): ()
	local payload = parsePayload(value)
	local frame = dialogueFrame
	if payload == nil or frame == nil then
		return
	end

	active = payload
	sectionIndex = 1
	showSection(payload, sectionIndex)
	local typeLabel = npcTypeLabel
	if typeLabel ~= nil then
		typeLabel.Text = payload.npcType
	end

	-- ปุ่มที่กำลังจะหลบอาจค้างขนาด hover อยู่ (เคอร์เซอร์ชี้ค้างตอนกล่องเด้ง)
	local main = mainFrame
	if main ~= nil then
		ButtonEffect.resetWithin(main)
	end
	UIAnimator.slideIn(frame, DIALOGUE_EDGE)
	setButtonsShown(false)
end

-- กด Continue: ไปท่อนถัดไป ถ้าเป็นท่อนสุดท้ายปิดกล่องแล้วบอก server ให้ NPC เดินออก
local function onContinue(): ()
	local payload = active
	if payload == nil then
		return -- ไม่มีบทสนทนา (เช่นกดรัวตอนกล่องกำลังเลื่อนลง)
	end
	if sectionIndex < #payload.info then
		sectionIndex += 1
		showSection(payload, sectionIndex)
		return
	end

	active = nil
	local frame = dialogueFrame
	if frame ~= nil then
		UIAnimator.slideOut(frame, DIALOGUE_EDGE)
		ButtonEffect.resetWithin(frame)
	end
	setButtonsShown(true)

	local remote = finishedRemote
	if remote ~= nil then
		remote:FireServer(payload.npcId)
	end
end

--[[
	เริ่มระบบ เรียกครั้งเดียวจาก UIController.init ผ่าน task.spawn (SafeFind อาจรอ ไม่ให้หน่วง UI)
	main = GUI.Main ที่ UIController หาไว้แล้ว (nil = หาไม่เจอ warn ไปแล้ว ข้ามทั้งระบบ)
]]
function DialogueController.init(main: GuiObject?): ()
	if initialized then
		return
	end
	initialized = true
	if main == nil then
		return
	end
	mainFrame = main

	local frame = SafeFind.path(main, "Dialogue", "GuiObject", CHILD_TIMEOUT) :: GuiObject?
	if frame == nil then
		return
	end
	dialogueFrame = frame
	infoLabel = SafeFind.path(frame, "Info", "TextLabel", CHILD_TIMEOUT) :: TextLabel?
	npcTypeLabel = SafeFind.path(frame, "NpcType", "TextLabel", CHILD_TIMEOUT) :: TextLabel?
	for _, name in HIDDEN_BUTTON_NAMES do
		local button = SafeFind.path(main, name, "GuiObject", CHILD_TIMEOUT) :: GuiObject?
		if button ~= nil then
			table.insert(hiddenButtons, button)
		end
	end

	-- ซ่อนกล่องไว้จนกว่าลูกค้าจะมา ไม่ว่าใน Studio จะเปิดค้างไว้หรือไม่
	UIAnimator.slideOut(frame, DIALOGUE_EDGE, true)

	local continueButton = SafeFind.path(frame, "ContinueButton", "GuiButton", CHILD_TIMEOUT) :: GuiButton?
	if continueButton ~= nil then
		continueButton.Activated:Connect(onContinue)
	end

	finishedRemote = SafeFind.path(ReplicatedStorage, "Remotes.DialogueFinished", "RemoteEvent") :: RemoteEvent?
	local showRemote = SafeFind.path(ReplicatedStorage, "Remotes.DialogueShow", "RemoteEvent") :: RemoteEvent?
	if showRemote ~= nil then
		showRemote.OnClientEvent:Connect(onDialogueShow)
	end
end

return table.freeze(DialogueController)
