--!strict
--[[
	CameraController.luau — กล้องของผู้เล่น (ปรับปรุงจาก FirstPersonCamera เดิม)

	เกมเป็น point-and-click ผู้เล่นไม่มีตัวละคร กล้องจึงยึดไว้กับ part ที่วางไว้ในแมพ
		โหมด Store    → Workspace.CamPart
		โหมด Workshop → Workspace.CamPart2
	เคอร์เซอร์อิสระ กล้องเอียงตามตำแหน่งเคอร์เซอร์ได้เล็กน้อย (UIController ปิดได้ตอนมีหน้าต่างเปิดอยู่)

	ย้ายกล้องระหว่างโหมดด้วยการ lerp ใน RenderStep เอง ไม่ใช้ TweenService
	เพราะ RenderStep เขียน Camera.CFrame ทับทุกเฟรม tween จะโดนทับจนไม่เห็นผล

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
local TRANSITION_TIME: number = 1 -- วินาทีที่ใช้ย้ายกล้องระหว่างโหมด
local RENDER_BIND_NAME: string = "CameraControllerUpdate"

local CameraController = {}

local initialized: boolean = false
local currentMode: CameraMode = "Store"
local lookEnabled: boolean = false

local parts: { [CameraMode]: BasePart } = {}
local missingParts: { [CameraMode]: boolean } = {} -- หาแล้วไม่เจอ = ใช้โหมดนั้นไม่ได้

local baseCFrame: CFrame? = nil -- ตำแหน่งกล้องก่อนเอียงตามเคอร์เซอร์ (nil = ยังไม่เคยวางกล้อง)
local transitionFrom: CFrame? = nil -- จุดเริ่มของการย้ายโหมด (nil = ไม่ได้กำลังย้าย)
local transitionElapsed: number = 0
local currentYaw: number = 0
local currentPitch: number = 0

-- ออกตัวช้า เร่งกลางทาง แล้วผ่อนตอนถึง กล้องจะไม่กระชาก
local function easeInOutCubic(t: number): number
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - ((-2 * t + 2) ^ 3) / 2
end

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

	-- ตำแหน่งฐาน: ระหว่างย้ายโหมด ค่อยๆ ไล่จากจุดเดิมไปหา part ของโหมดใหม่
	local base = part.CFrame
	local from = transitionFrom
	if from ~= nil then
		transitionElapsed += deltaTime
		local progress = transitionElapsed / TRANSITION_TIME
		if progress >= 1 then
			transitionFrom = nil
		else
			base = from:Lerp(base, easeInOutCubic(progress))
		end
	end
	baseCFrame = base

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

	camera.CFrame = base * CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
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
	ย้ายกล้องไปโหมดที่ต้องการ instant = วางทันที ไม่เลื่อน (ใช้ตอนเริ่มเกม)
	ถ้า part ของโหมดนั้นหาไม่เจอ จะ warn แล้วอยู่โหมดเดิม
]]
function CameraController.setMode(mode: CameraMode, instant: boolean?): ()
	if missingParts[mode] then
		warn(`[CameraController] ใช้โหมด {mode} ไม่ได้ เพราะหา Workspace.{MODES[mode].partName} ไม่เจอ`)
		return
	end
	if mode == currentMode and not instant then
		return
	end

	currentMode = mode
	-- เลื่อนจากตำแหน่งปัจจุบัน ถ้าสั่ง instant หรือยังไม่เคยวางกล้อง (baseCFrame = nil) จะวางทันที
	transitionFrom = if instant then nil else baseCFrame
	transitionElapsed = 0
end

-- เปิด/ปิดการเอียงกล้องตามเคอร์เซอร์ ปิดแล้วกล้องจะค่อยๆ กลับมามองตรง
function CameraController.setLookEnabled(enabled: boolean): ()
	lookEnabled = enabled
end

return table.freeze(CameraController)
