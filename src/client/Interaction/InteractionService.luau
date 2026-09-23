--!strict
--[[
	InteractionService.luau — คลิกวัตถุ 3D ด้วยการยิง raycast จากกล้องไปตามตำแหน่งเคอร์เซอร์
	ไม่ใช้ ClickDetector เพราะผู้เล่นไม่มีตัวละคร (ClickDetector วัดระยะจาก Character)

	ใช้งาน:
		InteractionService.register(computer, function() ... end, highlight)
	- เคอร์เซอร์ชี้โดน target (part ไหนข้างในก็ได้) → เปิด Highlight ที่ให้มา
	- คลิกโดน → เรียก onClick
	- คลิกที่ UI รับไปแล้ว (gameProcessedEvent) จะไม่ทะลุมาถึงวัตถุ 3D
	- part ที่ใสสนิทและไม่ใช่ target (เช่น CamPart2 หรือกำแพงล่องหน) ray จะทะลุผ่านไป
	  ส่วนของทึบที่ไม่ใช่ target จะบังการคลิกเหมือนของจริง

	UIController เป็นคนเปิด/ปิดระบบนี้ตามหน้าจอผ่าน setEnabled (ตอนเริ่มเกมปิดอยู่)
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RENDER_BIND_NAME: string = "InteractionHover"
local MAX_DISTANCE: number = 500 -- ระยะ ray (stud) ร้านเล็ก เท่านี้เหลือเฟือ
local MAX_PASS_THROUGH: number = 5 -- ทะลุ part ใสได้กี่ชั้น กัน loop ไม่จบ

type Registration = {
	onClick: () -> (),
	highlight: Highlight?,
}

local InteractionService = {}

local initialized: boolean = false
local enabled: boolean = false
local registrations: { [Instance]: Registration } = {}
local hovered: Registration? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ไล่ขึ้นจาก part ที่ ray โดน หา target ที่ลงทะเบียนไว้ (target เป็น Model ที่มีหลาย part ได้)
local function registrationOf(instance: Instance): Registration?
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		local registration = registrations[current]
		if registration ~= nil then
			return registration
		end
		current = current.Parent
	end
	return nil
end

-- ยิง ray แล้วคืน target ที่โดน (nil = ไม่โดน target ไหนเลย หรือมีของทึบบังอยู่)
local function findTarget(ray: Ray): Registration?
	local ignored: { Instance } = {}
	for _ = 1, MAX_PASS_THROUGH do
		rayParams.FilterDescendantsInstances = ignored
		local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_DISTANCE, rayParams)
		if result == nil then
			return nil
		end

		local registration = registrationOf(result.Instance)
		if registration ~= nil then
			return registration
		end
		if result.Instance.Transparency < 1 then
			return nil -- โดนของทึบที่ไม่ใช่ target = ถูกบัง
		end
		table.insert(ignored, result.Instance)
	end
	return nil
end

local function setHighlight(registration: Registration?, on: boolean): ()
	if registration == nil then
		return
	end
	local highlight = registration.highlight
	if highlight ~= nil then
		highlight.Enabled = on
	end
end

local function setHovered(registration: Registration?): ()
	if hovered == registration then
		return
	end
	setHighlight(hovered, false)
	hovered = registration
	setHighlight(registration, true)
end

-- ทุกเฟรม: ยิง ray ตามเคอร์เซอร์เพื่อไฮไลต์สิ่งที่ชี้อยู่
local function onRenderStep(_deltaTime: number): ()
	if not enabled then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- GetMouseLocation นับรวมแถบ topbar จึงต้องคู่กับ ViewportPointToRay
	local mouse = UserInputService:GetMouseLocation()
	setHovered(findTarget(camera:ViewportPointToRay(mouse.X, mouse.Y)))
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean): ()
	if not enabled or gameProcessedEvent then
		return -- UI รับคลิกนี้ไปแล้ว (เช่นกดโดนปุ่ม) ไม่ให้ทะลุมาถึงวัตถุ 3D
	end
	local inputType = input.UserInputType
	if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- input.Position ไม่นับแถบ topbar จึงต้องคู่กับ ScreenPointToRay (จับคู่ผิดแล้วจุดคลิกจะเพี้ยน)
	local registration = findTarget(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
	if registration ~= nil then
		registration.onClick()
	end
end

--[[
	ลงทะเบียนวัตถุ 3D ที่คลิกได้ target เป็น Model หรือ BasePart ก็ได้
	highlight (ถ้ามี) จะถูกปิดไว้ก่อน แล้วเปิดเฉพาะตอนเคอร์เซอร์ชี้
	คืนฟังก์ชันสำหรับยกเลิกการลงทะเบียน
]]
function InteractionService.register(target: Instance, onClick: () -> (), highlight: Highlight?): () -> ()
	local registration: Registration = { onClick = onClick, highlight = highlight }
	registrations[target] = registration
	setHighlight(registration, false)

	return function(): ()
		if registrations[target] == registration then
			registrations[target] = nil
		end
		if hovered == registration then
			setHovered(nil)
		end
	end
end

-- เปิด/ปิดการชี้และคลิกวัตถุ 3D ทั้งหมด (ปิดแล้ว Highlight ที่ค้างอยู่จะดับด้วย)
function InteractionService.setEnabled(value: boolean): ()
	enabled = value
	if not value then
		setHovered(nil)
	end
end

-- เริ่มระบบ เรียกครั้งเดียวจาก init.client.luau (เรียกซ้ำไม่มีผล)
function InteractionService.init(): ()
	if initialized then
		return
	end
	initialized = true

	-- ทำงานหลังกล้องอัปเดตแล้ว (CameraController ใช้ Camera + 1) ray จะตรงกับภาพในเฟรมนั้น
	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStep)
	UserInputService.InputBegan:Connect(onInputBegan)
end

return table.freeze(InteractionService)
