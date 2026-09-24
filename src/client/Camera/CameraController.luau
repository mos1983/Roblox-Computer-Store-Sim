--!strict
--[[
	CameraController.luau — กล้องของผู้เล่น (ปรับปรุงจาก FirstPersonCamera เดิม)

	เกมเป็น point-and-click ผู้เล่นไม่มีตัวละคร กล้องจึงยึดไว้กับ part ที่วางไว้ในแมพ
		โหมด Store    → Workspace.CamPart
		โหมด Workshop → Workspace.CamPart2
	เคอร์เซอร์อิสระ กล้องเอียงตามตำแหน่งเคอร์เซอร์ได้เล็กน้อย (UIController ปิดได้ตอนมีหน้าต่างเปิดอยู่)

	เปลี่ยนโหมดแล้วกล้องย้ายไปจุดใหม่ทันที ไม่เลื่อนผ่านระหว่างทาง เพราะ CamPart กับ CamPart2
	อยู่คนละห้อง เลื่อนไปจะทะลุกำแพง — UIController ใช้ LoadingScreen.transition() บังจอตอนย้าย (กฎใน CLAUDE.md)

	หา CamPart / CamPart2 ใน background ถ้าหาไม่เจอจะ warn และใช้โหมดนั้นไม่ได้ แต่ไม่ทำให้ระบบอื่นค้าง
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SafeFind = require(script.Parent.Parent.Util.SafeFind)

export type CameraMode = "Store" | "Workshop"

type ModeConfig = {
	partName: string, -- ชื่อ part ใต้ Workspace ที่กล้องไปยึด
	maxYawLeft: number, -- หันซ้ายได้สูงสุด (เมื่อเคอร์เซอร์อยู่ขอบจอ)
	maxYawRight: number, -- หันขวาได้สูงสุด
	maxPitch: number, -- ก้ม/เงยได้สูงสุด
}

local MODES: { [CameraMode]: ModeConfig } = {
	-- หันซ้ายได้เยอะเพราะ Computer อยู่ฝั่งซ้ายของร้าน
	Store = { partName = "CamPart", maxYawLeft = math.rad(40), maxYawRight = math.rad(1), maxPitch = math.rad(10) },
	-- ยังไม่ได้ใช้ (UIController ปิดการเอียงในโหมดนี้ไว้ก่อน) ค่อยปรับตอนทำ GUI ส่วน Workshop
	Workshop = { partName = "CamPart2", maxYawLeft = math.rad(10), maxYawRight = math.rad(10), maxPitch = math.rad(5) },
}

local LOOK_SMOOTHING: number = 8 -- ยิ่งมากยิ่งตามเคอร์เซอร์ไว
local RENDER_BIND_NAME: string = "CameraControllerUpdate"

local CameraController = {}

local initialized: boolean = false
local currentMode: CameraMode = "Store"
local lookEnabled: boolean = false

local parts: { [CameraMode]: BasePart } = {}
local missingParts: { [CameraMode]: boolean } = {} -- หาแล้วไม่เจอ = ใช้โหมดนั้นไม่ได้

local currentYaw: number = 0
local currentPitch: number = 0

local function onRenderStep(deltaTime: number): ()
	local camera = workspace.CurrentCamera
	local part = parts[currentMode]
	if camera == nil or part == nil then
		return -- ยังหา part ของโหมดนี้ไม่เจอ ปล่อยกล้องไว้ที่เดิม
	end

	-- กันสคริปต์กล้องของ Roblox แย่งคุมกล้องคืน
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- แปลงตำแหน่งเคอร์เซอร์เป็นช่วง -1..1 (0 = กลางจอ) แล้วคิดมุมที่อยากเอียงไป
	local targetYaw = 0
	local targetPitch = 0
	local viewport = camera.ViewportSize
	if lookEnabled and viewport.X > 0 and viewport.Y > 0 then
		local mouse = UserInputService:GetMouseLocation()
		local normalizedX = math.clamp((mouse.X / viewport.X) * 2 - 1, -1, 1)
		local normalizedY = math.clamp((mouse.Y / viewport.Y) * 2 - 1, -1, 1)
		local config = MODES[currentMode]
		local maxYaw = if normalizedX > 0 then config.maxYawRight else config.maxYawLeft
		targetYaw = -normalizedX * maxYaw
		targetPitch = -normalizedY * config.maxPitch
	end

	-- ค่อยๆ เอียงไปหาเป้าหมาย ไม่ให้กระตุก (ปิดการเอียงแล้วก็ค่อยๆ กลับมามองตรง)
	local alpha = math.min(deltaTime * LOOK_SMOOTHING, 1)
	currentYaw += (targetYaw - currentYaw) * alpha
	currentPitch += (targetPitch - currentPitch) * alpha

	camera.CFrame = part.CFrame * CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
end

--[[
	เริ่มระบบกล้อง เรียกครั้งเดียวจาก init.client.luau (เรียกซ้ำไม่มีผล)
	ไม่บล็อกผู้เรียก: หา part ใน background ระหว่างนั้นกล้องอยู่ที่เดิมไปก่อน
]]
function CameraController.init(): ()
	if initialized then
		return
	end
	initialized = true

	-- ตั้ง Scriptable ตอนรันเกมเท่านั้น (ถ้าตั้งใน Studio จะเลื่อนกล้อง edit mode ไม่ได้)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- แยก task ต่อโหมด part ไหนหาไม่เจอจะได้ไม่หน่วงอีกโหมด
	for mode, config in MODES do
		task.spawn(function(): ()
			local found = SafeFind.path(workspace, config.partName, "BasePart")
			if found == nil then
				missingParts[mode] = true
				return
			end

			local part = found :: BasePart
			if not part.Anchored then
				warn(`[CameraController] {SafeFind.describe(part)} ควร Anchored ไม่งั้นกล้องจะร่วงตาม part`)
			end
			parts[mode] = part
		end)
	end

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

--[[
	ย้ายกล้องไปโหมดที่ต้องการทันที (เฟรมถัดไป) และรีเซ็ตการเอียงกลับมามองตรง
	ต้องมีจอโหลดบังไว้ก่อน — เรียกผ่าน UIController.goTo() ซึ่งจัดการ LoadingScreen ให้
	ถ้า part ของโหมดนั้นหาไม่เจอ จะ warn แล้วอยู่โหมดเดิม
]]
function CameraController.setMode(mode: CameraMode): ()
	if missingParts[mode] then
		warn(`[CameraController] ใช้โหมด {mode} ไม่ได้ เพราะหา Workspace.{MODES[mode].partName} ไม่เจอ`)
		return
	end
	if mode == currentMode then
		-- โหมดเดิม (เช่น Store → Upgrade) ไม่รีเซ็ตการเอียง ไม่งั้นกล้องจะกระตุกกลับมามองตรง
		-- ปล่อยให้ setLookEnabled(false) ค่อยๆ หันกลับเอง
		return
	end

	currentMode = mode
	currentYaw = 0
	currentPitch = 0
end

-- เปิด/ปิดการเอียงกล้องตามเคอร์เซอร์ ปิดแล้วกล้องจะค่อยๆ กลับมามองตรง
function CameraController.setLookEnabled(enabled: boolean): ()
	lookEnabled = enabled
end

return table.freeze(CameraController)
