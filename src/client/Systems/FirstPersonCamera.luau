--!strict
-- FirstPersonCamera
-- ยึดกล้องไว้ที่ workspace.CamPart (ต้อง Anchored และตั้ง Camera.CameraType = Scriptable ไว้เอง)
-- เกมเป็น point-and-click: เคอร์เซอร์อิสระ กล้องเอียงตามตำแหน่งเคอร์เซอร์ได้เล็กน้อย ตัวละครขยับไม่ได้

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CamPart = workspace:WaitForChild("CamPart") :: BasePart

-- ค่าปรับแต่ง
local MAX_YAW_LEFT: number = math.rad(40) -- หันซ้ายได้สูงสุด (เมื่อเคอร์เซอร์อยู่ขอบจอ)
local MAX_YAW_RIGHT: number = math.rad(1) -- หันขวาได้สูงสุด
local MAX_PITCH: number = math.rad(10) -- ก้ม/เงยได้สูงสุด
local LOOK_SMOOTHING: number = 8 -- ยิ่งมากยิ่งตามเคอร์เซอร์ไว
local RENDER_BIND_NAME: string = "FirstPersonCameraUpdate"

local FirstPersonCamera = {}

local enabled: boolean = false
local currentYaw: number = 0
local currentPitch: number = 0
local characterConnection: RBXScriptConnection? = nil

-- ล็อก/ปลดล็อกการเคลื่อนที่ของตัวละคร
local function setMovementLocked(character: Model, locked: boolean): ()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = if locked then 0 else 16
	humanoid.JumpPower = if locked then 0 else 50
	humanoid.JumpHeight = if locked then 0 else 7.2
end

local function onRenderStep(deltaTime: number): ()
	-- แปลงตำแหน่งเคอร์เซอร์เป็นช่วง -1..1 (0 = กลางจอ)
	local viewport = Camera.ViewportSize
	local mouse = UserInputService:GetMouseLocation()
	local normalizedX = math.clamp((mouse.X / viewport.X) * 2 - 1, -1, 1)
	local normalizedY = math.clamp((mouse.Y / viewport.Y) * 2 - 1, -1, 1)

	-- ค่อยๆ เอียงกล้องไปหาเป้าหมาย ไม่ให้กระตุก
	local alpha = math.min(deltaTime * LOOK_SMOOTHING, 1)
	local maxYaw = if normalizedX > 0 then MAX_YAW_RIGHT else MAX_YAW_LEFT
	currentYaw += (-normalizedX * maxYaw - currentYaw) * alpha
	currentPitch += (-normalizedY * MAX_PITCH - currentPitch) * alpha

	Camera.CFrame = CamPart.CFrame * CFrame.Angles(0, currentYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
end

function FirstPersonCamera.Enable(): ()
	if enabled then
		return
	end
	enabled = true

	if not CamPart.Anchored then
		warn("CamPart ควร Anchored ไม่งั้นกล้องจะร่วง")
	end

	characterConnection = LocalPlayer.CharacterAdded:Connect(function(character: Model)
		setMovementLocked(character, true)
	end)
	if LocalPlayer.Character then
		task.spawn(setMovementLocked, LocalPlayer.Character, true)
	end

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

function FirstPersonCamera.Disable(): ()
	if not enabled then
		return
	end
	enabled = false

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if LocalPlayer.Character then
		setMovementLocked(LocalPlayer.Character, false)
	end
end

function FirstPersonCamera.IsEnabled(): boolean
	return enabled
end

return FirstPersonCamera
