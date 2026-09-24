--!strict
-- LoadingScreen
-- ตอนนี้สร้าง GUI ด้วยโค้ดเป็น placeholder
-- เมื่อออกแบบ Loading Screen จริงเสร็จแล้ว ให้วาง ScreenGui ชื่อ "Loading"
-- ไว้ใน StarterGui แล้วโมดูลนี้จะใช้ตัวนั้นแทนอัตโนมัติ
-- โดยไม่ต้องแก้โค้ดที่เรียกใช้
--[[
	จอโหลดเต็มจอ ใช้บังตอนเปลี่ยนฉาก/ย้ายจุดกล้อง (กฎใน CLAUDE.md: ห้ามเลื่อนกล้องข้ามจุดเพราะจะทะลุกำแพง)
	ปกติไม่ต้องเรียกเอง UIController.goTo() เรียก transition() ให้ทุกครั้งที่จุดกล้องเปลี่ยน

	ข้อตกลงสำหรับ GUI จริง:
	- TextLabel ที่จะใส่ข้อความ ตั้งชื่อว่า "Message" (อยู่ลึกแค่ไหนก็ได้) ไม่มีก็แค่ไม่เปลี่ยนข้อความ
	- ไม่ต้องทำ CanvasGroup เอง ตอน init โมดูลนี้จะย้ายลูกทั้งหมดเข้า CanvasGroup "Fade" ให้ จะได้ fade ทั้งก้อน
	- ตั้ง DisplayOrder ให้สูงกว่า GUI อื่น (placeholder ใช้ 500) และ IgnoreGuiInset = true จะได้บังทั้งจอ
	- จุดกะพริบมีเฉพาะ placeholder ถ้า GUI จริงอยากมี animation ให้เพิ่มในโมดูลนี้ (ห้ามฝัง LocalScript ใน GUI)
]]

local RunService = game:GetService("RunService")

local SafeFind = require(script.Parent.Parent.Util.SafeFind)
local UIAnimator = require(script.Parent.UIAnimator)

local GUI_NAME: string = "Loading"
local FADE_NAME: string = "Fade"
local MESSAGE_NAME: string = "Message"
local DEFAULT_TEXT: string = "กำลังโหลด"
local DEFAULT_HOLD_TIME: number = 0.5 -- วินาทีที่จอดำค้างไว้ก่อนเรียก middleCallback

-- หน้าตา placeholder
local DISPLAY_ORDER: number = 500
local BACKGROUND_COLOR: Color3 = Color3.fromRGB(15, 20, 30)
local TEXT_COLOR: Color3 = Color3.fromRGB(230, 235, 245)
local DOT_COUNT: number = 3
local DOT_SIZE: number = 10 -- pixel
local DOT_GAP: number = 10 -- pixel
local DOT_CYCLE: number = 1.2 -- วินาทีต่อหนึ่งรอบการไล่
local DOT_DIM_TRANSPARENCY: number = 0.8 -- จุดตอนจางสุด (0 = สว่างสุด)

local LoadingScreen = {}

local initialized: boolean = false
local screenGui: ScreenGui? = nil
local fader: CanvasGroup? = nil
local messageLabel: TextLabel? = nil
local defaultText: string = DEFAULT_TEXT
local wantShown: boolean = false

local dots: { Frame } = {}
local dotElapsed: number = 0
local dotConnection: RBXScriptConnection? = nil

-- จุดสามจุดสว่างไล่กันจากซ้ายไปขวา (animation วนไม่รู้จบ จึงคิดเองทุกเฟรมแทนการใช้ tween)
local function updateDots(deltaTime: number): ()
	dotElapsed += deltaTime
	for index, dot in dots do
		-- แต่ละจุดช้ากว่าจุดก่อนหน้า 1/DOT_COUNT รอบ
		local phase = dotElapsed / DOT_CYCLE - (index - 1) / #dots
		local brightness = (math.cos(phase * 2 * math.pi) + 1) / 2
		dot.BackgroundTransparency = DOT_DIM_TRANSPARENCY * (1 - brightness)
	end
end

local function startDots(): ()
	if dotConnection ~= nil or #dots == 0 then
		return
	end
	dotElapsed = 0
	dotConnection = RunService.Heartbeat:Connect(updateDots)
end

local function stopDots(): ()
	local connection = dotConnection
	if connection ~= nil then
		dotConnection = nil
		connection:Disconnect()
	end
end

-- สร้าง placeholder: ScreenGui > Background (Frame เต็มจอ) > Message + Dots
local function buildPlaceholder(playerGui: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = BACKGROUND_COLOR
	background.BorderSizePixel = 0
	background.Active = true -- บล็อกคลิกไม่ให้ทะลุไปโดนปุ่ม/วัตถุ 3D ข้างหลัง
	background.Parent = gui

	local message = Instance.new("TextLabel")
	message.Name = MESSAGE_NAME
	message.AnchorPoint = Vector2.new(0.5, 1)
	message.Position = UDim2.fromScale(0.5, 0.5)
	message.Size = UDim2.new(0.8, 0, 0, 40)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamMedium
	message.TextSize = 28
	message.TextColor3 = TEXT_COLOR
	message.Text = DEFAULT_TEXT
	message.Parent = background

	local dotRow = Instance.new("Frame")
	dotRow.Name = "Dots"
	dotRow.AnchorPoint = Vector2.new(0.5, 0)
	dotRow.Position = UDim2.new(0.5, 0, 0.5, 16)
	dotRow.Size = UDim2.fromOffset(DOT_COUNT * DOT_SIZE + (DOT_COUNT - 1) * DOT_GAP, DOT_SIZE)
	dotRow.BackgroundTransparency = 1
	dotRow.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, DOT_GAP)
	layout.Parent = dotRow

	for index = 1, DOT_COUNT do
		local dot = Instance.new("Frame")
		dot.Name = `Dot{index}`
		dot.LayoutOrder = index
		dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		dot.BackgroundColor3 = TEXT_COLOR
		dot.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dot

		dot.Parent = dotRow
		table.insert(dots, dot)
	end

	gui.Parent = playerGui
	return gui
end

--[[
	เตรียม ScreenGui (placeholder หรือ GUI จริงก็ได้) ให้พร้อมใช้: ครอบด้วย CanvasGroup "Fade" แล้วซ่อนไว้
	หา TextLabel "Message" แบบ recursive ถ้าไม่เจอจะ warn ครั้งเดียวแล้วข้ามการใส่ข้อความตลอด
]]
local function attach(gui: ScreenGui): ()
	local existing = gui:FindFirstChild(FADE_NAME)
	local fade: CanvasGroup
	if existing ~= nil and existing:IsA("CanvasGroup") then
		fade = existing :: CanvasGroup
	else
		fade = Instance.new("CanvasGroup")
		fade.Name = FADE_NAME
		fade.Size = UDim2.fromScale(1, 1)
		fade.BackgroundTransparency = 1
		fade.BorderSizePixel = 0
		for _, child in gui:GetChildren() do
			child.Parent = fade
		end
		fade.Parent = gui
	end
	fade.Active = true -- บล็อกคลิกทั้งจอระหว่างโหลด ไม่ว่า GUI ข้างในจะตั้ง Active ไว้หรือไม่
	fade.GroupTransparency = 1
	gui.Enabled = false

	local message = gui:FindFirstChild(MESSAGE_NAME, true)
	if message ~= nil and message:IsA("TextLabel") then
		local label = message :: TextLabel
		messageLabel = label
		defaultText = label.Text
	else
		warn(`[LoadingScreen] ไม่เจอ TextLabel ชื่อ "{MESSAGE_NAME}" ใน {SafeFind.describe(gui)} จะแสดงจอโหลดโดยไม่ใส่ข้อความ`)
	end

	screenGui = gui
	fader = fade
end

--[[
	เรียกครั้งเดียวจาก UIController.init หลังหา PlayerGui.Title / GUI เจอแล้ว
	(ของใน StarterGui ถูก clone มาพร้อมกัน ถึงตอนนั้น PlayerGui.Loading ตัวจริงถ้ามีก็มาถึงแล้ว)
	มี PlayerGui.Loading อยู่แล้ว = ใช้ตัวนั้น ไม่มี = สร้าง placeholder
]]
function LoadingScreen.init(playerGui: Instance): ()
	if initialized then
		return
	end
	initialized = true

	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing ~= nil and existing:IsA("ScreenGui") then
		attach(existing :: ScreenGui)
		return
	end
	if existing ~= nil then
		warn(`[LoadingScreen] {SafeFind.describe(existing)} เป็น {existing.ClassName} ไม่ใช่ ScreenGui ใช้ placeholder แทน`)
	end
	attach(buildPlaceholder(playerGui))
end

-- แสดงจอโหลด (fade in 0.3 วินาที) แล้วรอจน fade จบ text = nil ใช้ข้อความตั้งต้นของ GUI
function LoadingScreen.show(text: string?): ()
	local gui = screenGui
	local fade = fader
	if gui == nil or fade == nil then
		return -- init ไม่สำเร็จ (warn ไปแล้ว)
	end

	local label = messageLabel
	if label ~= nil then
		label.Text = text or defaultText
	end

	wantShown = true
	if not gui.Enabled then
		fade.GroupTransparency = 1
		gui.Enabled = true
	end
	startDots()
	UIAnimator.fadeIn(fade).Completed:Wait()
end

-- ซ่อนจอโหลด (fade out 0.3 วินาที) แล้วรอจน fade จบ ถ้ามี show() แทรกเข้ามาระหว่างจางจะไม่ปิดทับ
function LoadingScreen.hide(): ()
	local gui = screenGui
	local fade = fader
	if gui == nil or fade == nil then
		return
	end

	wantShown = false
	if not gui.Enabled then
		return
	end
	UIAnimator.fadeOut(fade).Completed:Wait()
	if not wantShown then
		gui.Enabled = false
		stopDots()
	end
end

--[[
	ฟังก์ชันหลักสำหรับเปลี่ยนฉาก: show → รอ holdTime (ค่าเริ่มต้น 0.5 วินาที) → middleCallback → hide
	รอจนจอโหลดหายไปหมดแล้วค่อยคืนค่า
	middleCallback error จะ warn แล้วยัง hide ต่อ จอจะไม่ค้างดำ
]]
function LoadingScreen.transition(text: string?, middleCallback: () -> (), holdTime: number?): ()
	LoadingScreen.show(text)
	task.wait(holdTime or DEFAULT_HOLD_TIME)

	local ok, message = pcall(middleCallback)
	if not ok then
		warn(`[LoadingScreen] เปลี่ยนฉากไม่สำเร็จ: {message}`)
	end

	LoadingScreen.hide()
end

return table.freeze(LoadingScreen)
