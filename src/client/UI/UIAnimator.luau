--!strict
--[[
	UIAnimator.luau — ไฟล์เดียวในเกมที่เรียก TweenService (กฎใน CLAUDE.md)
	ไฟล์อื่นที่อยากขยับ UI ต้องเรียกผ่านฟังก์ชันในนี้

	- slideIn / slideOut : เลื่อน frame เข้า-ออกทางขอบบนหรือขอบล่างของจอ
	  ขยับด้วย Position จึงไม่ขึ้นกับ AnchorPoint ที่ตั้งไว้ใน Studio
	  ไม่ใช้วิธี fade เพราะ Frame ไม่มี GroupTransparency (มีแค่ CanvasGroup)
	- scaleTo : ขยาย/หดรอบขนาดเดิมผ่าน UIScale ใช้กับเอฟเฟกต์ปุ่ม

	tween ใหม่บน instance เดิมจะยกเลิกตัวเก่าก่อนเสมอ กดรัวๆ ก็ไม่ตีกัน
	และหน้าจอจะจบที่สถานะของคำสั่งล่าสุดเสมอ
]]

local TweenService = game:GetService("TweenService")

export type Edge = "Top" | "Bottom"

-- เลื่อนไปหนึ่งช่วงความสูงของ parent (ScreenGui = ทั้งจอ) จะพ้นขอบจอพอดีไม่ว่าจอสูงเท่าไร
local EDGE_OFFSETS: { [Edge]: UDim2 } = {
	Top = UDim2.fromScale(0, -1),
	Bottom = UDim2.fromScale(0, 1),
}

local SLIDE_IN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local SCALE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ตารางแบบ weak key: instance ที่ถูกลบไปแล้วจะหลุดออกจากตารางเอง ไม่ค้างในหน่วยความจำ
local WEAK_KEYS = { __mode = "k" }
local activeTweens: { [Instance]: Tween } = setmetatable({}, WEAK_KEYS) :: any
local homePositions: { [GuiObject]: UDim2 } = setmetatable({}, WEAK_KEYS) :: any
local baseScales: { [UIScale]: number } = setmetatable({}, WEAK_KEYS) :: any
local wantShown: { [GuiObject]: boolean } = setmetatable({}, WEAK_KEYS) :: any

local UIAnimator = {}

-- ยกเลิก tween ที่กำลังเล่นอยู่บน instance นี้ (ถ้ามี)
function UIAnimator.cancel(instance: Instance): ()
	local running = activeTweens[instance]
	if running ~= nil then
		activeTweens[instance] = nil
		running:Cancel()
	end
end

-- สร้างแล้วเล่น tween — ทุกฟังก์ชันในไฟล์นี้ผ่านตัวนี้ ยกเลิก tween เก่าของ instance เดิมก่อนเสมอ
function UIAnimator.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	UIAnimator.cancel(instance)

	local tween = TweenService:Create(instance, info, goals)
	activeTweens[instance] = tween
	tween.Completed:Connect(function(): ()
		if activeTweens[instance] == tween then
			activeTweens[instance] = nil
		end
	end)
	tween:Play()

	return tween
end

-- ตำแหน่งที่ออกแบบไว้ใน Studio จดไว้ตั้งแต่ครั้งแรกที่แตะ เลื่อนเข้าออกกี่รอบก็กลับมาที่เดิมเป๊ะ
local function homeOf(guiObject: GuiObject): UDim2
	local home = homePositions[guiObject]
	if home ~= nil then
		return home
	end
	homePositions[guiObject] = guiObject.Position
	return guiObject.Position
end

--[[
	เลื่อน guiObject เข้ามาจากขอบ from แล้วแสดง (instant = แสดงทันที ไม่มี animation)
	ถ้ากำลังเลื่อนออกค้างอยู่กลางทาง จะเลื่อนกลับจากจุดนั้นเลย ไม่กระโดดไปขอบจอก่อน
]]
function UIAnimator.slideIn(guiObject: GuiObject, from: Edge, instant: boolean?): ()
	local home = homeOf(guiObject)
	wantShown[guiObject] = true

	if instant then
		UIAnimator.cancel(guiObject)
		guiObject.Position = home
		guiObject.Visible = true
		return
	end

	if not guiObject.Visible then
		guiObject.Position = home + EDGE_OFFSETS[from]
		guiObject.Visible = true
	end
	UIAnimator.tween(guiObject, SLIDE_IN_INFO, { Position = home })
end

--[[
	เลื่อน guiObject ออกทางขอบ to แล้วซ่อน (instant = ซ่อนทันที)
	ซ่อนเสร็จแล้วคืน Position เดิมไว้ให้ ถ้ามีอะไรไปเปิด Visible ตรงๆ จะได้โผล่ถูกที่
]]
function UIAnimator.slideOut(guiObject: GuiObject, to: Edge, instant: boolean?): ()
	local home = homeOf(guiObject)
	wantShown[guiObject] = false

	if instant or not guiObject.Visible then
		UIAnimator.cancel(guiObject)
		guiObject.Visible = false
		guiObject.Position = home
		return
	end

	local tween = UIAnimator.tween(guiObject, SLIDE_OUT_INFO, { Position = home + EDGE_OFFSETS[to] })
	tween.Completed:Connect(function(playbackState: Enum.PlaybackState): ()
		-- เช็ค wantShown ด้วย เพราะ Completed อาจมาช้ากว่าคำสั่ง slideIn ที่ตามมา (deferred event)
		if playbackState == Enum.PlaybackState.Completed and wantShown[guiObject] == false then
			guiObject.Visible = false
			guiObject.Position = home
		end
	end)
end

--[[
	UIScale ของ guiObject พร้อมขนาดฐาน ถ้ายังไม่มีจะสร้างให้
	ถ้าใน Studio ใส่ UIScale ไว้เองแล้ว (เช่นปรับขนาดตามจอ) จะใช้ตัวเดิมและคูณจากค่าเดิมของมัน
]]
local function scaleOf(guiObject: GuiObject): (UIScale, number)
	local existing = guiObject:FindFirstChildOfClass("UIScale") :: UIScale?
	if existing == nil then
		local created = Instance.new("UIScale")
		created.Parent = guiObject
		baseScales[created] = 1
		return created, 1
	end

	local base = baseScales[existing]
	if base ~= nil then
		return existing, base
	end
	baseScales[existing] = existing.Scale
	return existing, existing.Scale
end

-- ขยาย/หดเทียบกับขนาดฐาน เช่น factor 1.06 = ใหญ่ขึ้น 6% (ใช้กับเอฟเฟกต์ปุ่ม)
function UIAnimator.scaleTo(guiObject: GuiObject, factor: number): ()
	local uiScale, base = scaleOf(guiObject)
	UIAnimator.tween(uiScale, SCALE_INFO, { Scale = base * factor })
end

return table.freeze(UIAnimator)
