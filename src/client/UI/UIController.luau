--!strict
--[[
	UIController.luau — ศูนย์กลางของหน้าจอทั้งหมด
	เปลี่ยนหน้าจอผ่าน UIController.goTo() เท่านั้น (กฎใน CLAUDE.md)

	หน้าจอแต่ละหน้ากำหนดไว้ในตาราง SCREENS ที่เดียว: UI ไหนแสดง กล้องอยู่โหมดไหน
	เอียงกล้องตามเคอร์เซอร์ได้ไหม คลิกวัตถุ 3D ได้ไหม — จะเพิ่มหน้าใหม่ก็แค่เพิ่มแถว
	ถ้าหน้าใหม่กล้องอยู่คนละโหมดกับหน้าเดิม goTo จะใช้ LoadingScreen.transition() บังจอให้เอง

	GUI อยู่บน Roblox cloud: หา instance ผ่าน SafeFind ถ้าไม่เจอจะ warn แล้วข้ามเฉพาะส่วนนั้น
	ปุ่มทุกตัวผูกจากไฟล์นี้ ห้ามฝัง LocalScript ไว้ในปุ่ม
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafeFind = require(script.Parent.Parent.Util.SafeFind)
local UIAnimator = require(script.Parent.UIAnimator)
local ButtonEffect = require(script.Parent.ButtonEffect)
local LoadingScreen = require(script.Parent.LoadingScreen)
local DialogueController = require(script.Parent.DialogueController)
local CameraController = require(script.Parent.Parent.Camera.CameraController)
local InteractionService = require(script.Parent.Parent.Interaction.InteractionService)

export type ScreenName = "Title" | "Store" | "Upgrade" | "Workshop"

type ScreenState = {
	title: boolean, -- PlayerGui.Title.Enabled
	main: boolean, -- GUI.Main.Visible
	upgrade: boolean, -- GUI.Upgrade.Visible
	blur: boolean, -- เบลอฉากหลัง (BlurEffect "UIBlur" ใน Lighting)
	camera: CameraController.CameraMode,
	look: boolean, -- เอียงกล้องตามเคอร์เซอร์
	interact: boolean, -- คลิกวัตถุ 3D ได้
	loadingText: string?, -- ข้อความบนจอโหลด ตอนเข้าหน้านี้จากหน้าที่กล้องอยู่คนละโหมด
}

--[[
	สถานะของทุกหน้าจอ (GUI.Enabled เปิดค้างตลอด จึงไม่อยู่ในตาราง)
	- Upgrade : Main เลื่อนลงไปหลบ ฉากหลังเบลอ ปิด Upgrade แล้ว Main เลื่อนกลับขึ้นมาและภาพชัดเหมือนเดิม
	- Workshop: เข้าผ่านจอโหลด ยังไม่มีปุ่มกลับ (ทำใน GUI Part2) ตอนนี้จึงปิดการเอียงกล้องและการคลิกไว้ก่อน
	  loadingText ของ Store เตรียมไว้ให้ปุ่มกลับจาก Workshop
	- Main.SettingButton ยังไม่มีหน้า Setting ปล่อยไว้ไม่ผูกอะไร
]]
local SCREENS: { [ScreenName]: ScreenState } = {
	Title = { title = true, main = false, upgrade = false, blur = false, camera = "Store", look = false, interact = false },
	Store = {
		title = false, main = true, upgrade = false, blur = false, camera = "Store", look = true, interact = true,
		loadingText = "กำลังกลับสู่หน้าร้าน",
	},
	Upgrade = { title = false, main = false, upgrade = true, blur = true, camera = "Store", look = false, interact = false },
	Workshop = {
		title = false, main = false, upgrade = false, blur = false, camera = "Workshop", look = false, interact = false,
		loadingText = "กำลังเข้าสู่ห้องประกอบ",
	},
}

-- ขอบจอที่ frame เลื่อนเข้า-ออก: Main หลบลงขอบล่าง ส่วน Upgrade ลงมาจากขอบบน
local MAIN_EDGE: UIAnimator.Edge = "Bottom"
local UPGRADE_EDGE: UIAnimator.Edge = "Top"

-- ScreenGui ถูก clone มาทั้งก้อน ถ้าตัวแม่มาแล้วแต่หาลูกไม่เจอ แปลว่าชื่อผิด ไม่ต้องรอนาน
local CHILD_TIMEOUT: number = 2

local UIController = {}

local initialized: boolean = false
local current: ScreenName? = nil
local transitioning: boolean = false -- กำลังอยู่หลังจอโหลด
local pendingScreen: ScreenName? = nil -- คำสั่ง goTo ที่เข้ามาระหว่างจอโหลด ทำต่อหลังจอโหลดหายไป

local titleGui: ScreenGui? = nil
local mainFrame: GuiObject? = nil
local upgradeFrame: GuiObject? = nil

local function setFrameShown(frame: GuiObject?, shown: boolean, edge: UIAnimator.Edge, instant: boolean?): ()
	if frame == nil then
		return -- หาไม่เจอตั้งแต่ตอน init (SafeFind warn ไปแล้ว)
	end
	if shown then
		UIAnimator.slideIn(frame, edge, instant)
	else
		UIAnimator.slideOut(frame, edge, instant)
		ButtonEffect.resetWithin(frame)
	end
end

-- ใช้สถานะของหน้าจอ ยกเว้น interact ที่ goTo คุมเอง เพราะต้องปิดไว้ตลอดช่วงจอโหลด
local function applyScreen(state: ScreenState, instant: boolean?): ()
	-- Title เป็น ScreenGui ใช้ .Enabled (tween ไม่ได้)
	local title = titleGui
	if title ~= nil then
		title.Enabled = state.title
		if not state.title then
			ButtonEffect.resetWithin(title)
		end
	end
	setFrameShown(mainFrame, state.main, MAIN_EDGE, instant)
	setFrameShown(upgradeFrame, state.upgrade, UPGRADE_EDGE, instant)
	if state.blur then
		UIAnimator.blurIn(instant)
	else
		UIAnimator.blurOut(instant)
	end

	CameraController.setMode(state.camera)
	CameraController.setLookEnabled(state.look)
end

--[[
	เปลี่ยนไปหน้าจอ screen (instant = ข้าม animation ทั้งหมด ใช้ตอนเริ่มเกม)
	ถ้ากล้องต้องย้ายจุด (เช่น Store → Workshop) จะเอา LoadingScreen บังจอ แล้วเปลี่ยนทุกอย่างทันทีหลังจอ
	ห้ามเลื่อนกล้องข้ามจุดเพราะจะทะลุกำแพง (กฎใน CLAUDE.md) ระหว่างนั้นปิดการคลิกวัตถุ 3D ไว้
	ไม่ yield: จอโหลดทำงานใน task แยก ผู้เรียกไม่ต้องรอ
	เรียกซ้อนได้ ผลสุดท้ายเป็นของคำสั่งล่าสุดเสมอ (ระหว่างจอโหลด คำสั่งใหม่จะรอทำต่อหลังจอโหลดหายไป)
]]
function UIController.goTo(screen: ScreenName, instant: boolean?): ()
	local state = SCREENS[screen]
	if state == nil then
		warn(`[UIController] ไม่รู้จักหน้าจอ "{screen}"`)
		return
	end
	if transitioning then
		pendingScreen = screen
		return
	end
	if screen == current and not instant then
		return
	end
	local previous = current
	current = screen

	local cameraMoves = previous ~= nil and SCREENS[previous].camera ~= state.camera
	if instant or not cameraMoves then
		applyScreen(state, instant)
		InteractionService.setEnabled(state.interact)
		return
	end

	transitioning = true
	InteractionService.setEnabled(false)
	task.spawn(function(): ()
		LoadingScreen.transition(state.loadingText, function(): ()
			applyScreen(state, true) -- อยู่หลังจอโหลดแล้ว ไม่ต้องมี animation
		end)
		transitioning = false
		InteractionService.setEnabled(state.interact)

		local pending = pendingScreen
		pendingScreen = nil
		if pending ~= nil then
			UIController.goTo(pending)
		end
	end)
end

-- หน้าจอที่แสดงอยู่ตอนนี้ (nil = ยังไม่ได้ init)
function UIController.getCurrent(): ScreenName?
	return current
end

-- ผูกปุ่มจาก path ใต้ parent (parent เป็น nil = หาตัวแม่ไม่เจอ warn ไปแล้ว ข้ามได้เลย)
local function bindButton(parent: Instance?, path: string, onActivated: () -> ()): ()
	if parent == nil then
		return
	end
	local button = SafeFind.path(parent, path, "GuiButton", CHILD_TIMEOUT) :: GuiButton?
	if button ~= nil then
		button.Activated:Connect(onActivated)
	end
end

-- ใส่ ButtonEffect ให้ทุกปุ่มใต้ root รวมถึงปุ่มที่ถูกสร้างเพิ่มทีหลัง
local function applyButtonEffects(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") then
			ButtonEffect.apply(descendant)
		end
	end
	root.DescendantAdded:Connect(function(descendant: Instance): ()
		if descendant:IsA("GuiButton") then
			ButtonEffect.apply(descendant)
		end
	end)
end

-- เตือนถ้ายังมีสคริปต์ฝังอยู่ใน GUI (เช่น OnClick ใน Title.Buttons.Play) ต้องไปลบเองใน Studio
local function warnEmbeddedScripts(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BaseScript") then
			warn(`[UIController] เจอสคริปต์ฝังอยู่ใน GUI: {SafeFind.describe(descendant)} ควรลบใน Studio เพราะปุ่มทุกตัวคุมผ่าน UIController แล้ว`)
		end
	end
end

-- บอก server ว่าผู้เล่นกด Play แล้ว (เริ่มนับเวลา spawn ลูกค้า) เรียกผ่าน task.spawn เพราะ SafeFind อาจรอ
local function notifyGameStarted(): ()
	local remote = SafeFind.path(ReplicatedStorage, "Remotes.GameStarted", "RemoteEvent") :: RemoteEvent?
	if remote ~= nil then
		remote:FireServer()
	end
end

-- Computer อยู่ใน Workspace อาจต้องรอโหลด จึงเรียกผ่าน task.spawn ไม่ให้หน่วงส่วน UI
local function registerComputer(): ()
	local computer = SafeFind.path(workspace, "Store.Furnitures.Computer")
	if computer == nil then
		return
	end
	-- ไม่มี Highlight ก็ยังคลิกได้ แค่ไม่มีไฮไลต์ตอนชี้
	local highlight = SafeFind.path(computer, "Highlight", "Highlight", CHILD_TIMEOUT) :: Highlight?
	InteractionService.register(computer, function(): ()
		UIController.goTo("Upgrade")
	end, highlight)
end

--[[
	เริ่มระบบ UI เรียกครั้งเดียวจาก init.client.luau หลัง CameraController และ InteractionService
	ลำดับ: หา ScreenGui/frame หลัก → เตรียมจอโหลด → เข้าหน้า Title ทันที → ผูกปุ่ม → ใส่เอฟเฟกต์ปุ่ม
	→ ลงทะเบียน Computer → เริ่ม DialogueController
	ปุ่ม Play ส่ง Remotes.GameStarted ให้ server เริ่มส่งลูกค้า
]]
function UIController.init(): ()
	if initialized then
		return
	end
	initialized = true

	local playerGui = SafeFind.path(Players.LocalPlayer, "PlayerGui", "PlayerGui")
	if playerGui == nil then
		return
	end

	titleGui = SafeFind.path(playerGui, "Title", "ScreenGui") :: ScreenGui?
	local gui = SafeFind.path(playerGui, "GUI", "ScreenGui") :: ScreenGui?
	if gui ~= nil then
		gui.Enabled = true -- เปิดค้างไว้ตลอด สลับหน้าด้วย Visible ของ frame ข้างในแทน
		mainFrame = SafeFind.path(gui, "Main", "GuiObject", CHILD_TIMEOUT) :: GuiObject?
		upgradeFrame = SafeFind.path(gui, "Upgrade", "GuiObject", CHILD_TIMEOUT) :: GuiObject?
	end

	-- ต้องมาหลังหา Title/GUI เจอ: ของใน StarterGui มาพร้อมกัน PlayerGui.Loading ตัวจริง (ถ้ามี) จะมาถึงแล้ว
	LoadingScreen.init(playerGui)

	-- เข้าหน้า Title ทันที ไม่ว่าใน Studio จะเปิด/ปิด frame ไหนค้างไว้
	UIController.goTo("Title", true)

	bindButton(titleGui, "Buttons.Play", function(): ()
		UIController.goTo("Store")
		task.spawn(notifyGameStarted)
	end)
	bindButton(mainFrame, "WorkshopButton", function(): ()
		UIController.goTo("Workshop")
	end)
	bindButton(upgradeFrame, "Body.Header.Close", function(): ()
		UIController.goTo("Store")
	end)

	local title = titleGui
	if title ~= nil then
		applyButtonEffects(title)
		warnEmbeddedScripts(title)
	end
	if gui ~= nil then
		applyButtonEffects(gui)
		warnEmbeddedScripts(gui)
	end

	task.spawn(registerComputer)
	task.spawn(DialogueController.init, mainFrame)
end

return table.freeze(UIController)
