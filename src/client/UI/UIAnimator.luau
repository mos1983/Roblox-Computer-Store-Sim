--!strict
--[[
	UIAnimator.luau — ไฟล์เดียวในเกมที่เรียก TweenService (กฎใน CLAUDE.md)
	ไฟล์อื่นที่อยากขยับ UI ต้องเรียกผ่านฟังก์ชันในนี้

	- slideIn / slideOut : เลื่อน frame เข้า-ออกทางขอบบนหรือขอบล่างของจอ
	  ขยับด้วย Position จึงไม่ขึ้นกับ AnchorPoint ที่ตั้งไว้ใน Studio
	  ไม่ใช้วิธี fade เพราะ Frame ไม่มี GroupTransparency (มีแค่ CanvasGroup)
	- scaleTo : ขยาย/หดรอบขนาดเดิมผ่าน UIScale ใช้กับเอฟเฟกต์ปุ่ม
	- blurIn / blurOut : เบลอฉากหลัง (โลก 3D) ผ่าน BlurEffect "UIBlur" ใน Lighting — GUI ไม่ถูกเบลอ
	- highlightIn / highlightOut : ค่อยๆ แสดง/จาง Highlight ของวัตถุ 3D (InteractionService ใช้ตอนชี้)
	- fadeIn / fadeOut : ค่อยๆ แสดง/ซ่อน CanvasGroup ทั้งก้อนด้วย GroupTransparency (LoadingScreen ใช้)

	tween ใหม่บน instance เดิมจะยกเลิกตัวเก่าก่อนเสมอ กดรัวๆ ก็ไม่ตีกัน
	และหน้าจอจะจบที่สถานะของคำสั่งล่าสุดเสมอ
	ข้อควรระวัง: ยกเลิกตาม instance ไม่ใช่ตาม property ถ้าวันหน้ามีสองฟังก์ชัน tween คนละ property
	บน instance เดียวกัน (เช่น fade กับ slide บน frame เดียว) ตัวหลังจะยกเลิกตัวแรกทิ้ง
]]

local Lighting = game:GetService("Lighting")
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
local BLUR_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIGHLIGHT_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local BLUR_NAME: string = "UIBlur"
local BLUR_SIZE: number = 18

-- ค่า transparency ของ Highlight ตอนแสดง (1 = ใสสนิท = ซ่อน)
local HIGHLIGHT_FILL_SHOWN: number = 0.75
local HIGHLIGHT_OUTLINE_SHOWN: number = 0
local HIGHLIGHT_HIDDEN: number = 1

-- ตารางแบบ weak key: instance ที่ถูกลบไปแล้วจะหลุดออกจากตารางเอง ไม่ค้างในหน่วยความจำ
local WEAK_KEYS = { __mode = "k" }
local activeTweens: { [Instance]: Tween } = setmetatable({}, WEAK_KEYS) :: any
local homePositions: { [GuiObject]: UDim2 } = setmetatable({}, WEAK_KEYS) :: any
local baseScales: { [UIScale]: number } = setmetatable({}, WEAK_KEYS) :: any
local wantShown: { [GuiObject]: boolean } = setmetatable({}, WEAK_KEYS) :: any
local blurEffect: BlurEffect? = nil

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

--[[
	BlurEffect "UIBlur" ใน Lighting ถ้ายังไม่มีจะสร้างให้ (สร้างฝั่ง client จึงเบลอเฉพาะจอผู้เล่นคนนี้)
	Enabled เปิดค้างไว้ตลอด คุมความเบลอด้วย Size อย่างเดียว
	ห้ามปิด Enabled ตอนเบลอออก เพราะถ้าปิดตอน tween ยังไม่จบภาพจะกระพริบ
]]
local function blurOf(): BlurEffect
	local cached = blurEffect
	if cached ~= nil and cached.Parent == Lighting then
		return cached
	end

	local found = Lighting:FindFirstChild(BLUR_NAME)
	local blur: BlurEffect
	if found ~= nil and found:IsA("BlurEffect") then
		blur = found :: BlurEffect
	else
		blur = Instance.new("BlurEffect")
		blur.Name = BLUR_NAME
		blur.Size = 0
		blur.Parent = Lighting
	end
	blur.Enabled = true
	blurEffect = blur
	return blur
end

-- tween ต่อจากค่าปัจจุบัน ถ้าสั่งกลับทางตอนกำลังเบลอออกครึ่งทาง จะไม่กระโดดไป 0 ก่อน
local function setBlurSize(size: number, instant: boolean?): ()
	local blur = blurOf()
	if instant then
		UIAnimator.cancel(blur)
		blur.Size = size
		return
	end
	UIAnimator.tween(blur, BLUR_INFO, { Size = size })
end

-- เบลอฉากหลังขึ้นไปที่ BLUR_SIZE ใน 0.35 วินาที (instant = เบลอทันที)
function UIAnimator.blurIn(instant: boolean?): ()
	setBlurSize(BLUR_SIZE, instant)
end

-- เบลอกลับเป็น 0 ใช้เวลาเท่ากับ blurIn (instant = ชัดทันที)
function UIAnimator.blurOut(instant: boolean?): ()
	setBlurSize(0, instant)
end

--[[
	Highlight เปิด Enabled ค้างไว้ตลอด คุมด้วย FillTransparency + OutlineTransparency อย่างเดียว
	ทั้งสองค่าอยู่ใน tween ตัวเดียวกัน จึงยกเลิกพร้อมกันเสมอ ชี้เข้าออกรัวๆ ค่าไม่กระตุกสู้กัน
	และ tween ต่อจากค่าปัจจุบัน ถ้าออกกลางทางจะจางจากจุดนั้นเลย
]]
local function setHighlightTransparency(highlight: Highlight, fill: number, outline: number, instant: boolean?): ()
	highlight.Enabled = true
	if instant then
		UIAnimator.cancel(highlight)
		highlight.FillTransparency = fill
		highlight.OutlineTransparency = outline
		return
	end
	UIAnimator.tween(highlight, HIGHLIGHT_INFO, { FillTransparency = fill, OutlineTransparency = outline })
end

-- ค่อยๆ แสดง Highlight ใน 0.2 วินาที (instant = แสดงทันที)
function UIAnimator.highlightIn(highlight: Highlight, instant: boolean?): ()
	setHighlightTransparency(highlight, HIGHLIGHT_FILL_SHOWN, HIGHLIGHT_OUTLINE_SHOWN, instant)
end

-- ค่อยๆ จาง Highlight จนใสสนิท ใช้เวลาเท่ากับ highlightIn (instant = ซ่อนทันที)
function UIAnimator.highlightOut(highlight: Highlight, instant: boolean?): ()
	setHighlightTransparency(highlight, HIGHLIGHT_HIDDEN, HIGHLIGHT_HIDDEN, instant)
end

-- ค่อยๆ แสดง CanvasGroup ใน 0.3 วินาที คืน Tween ไว้ให้ผู้เรียกรอ Completed ได้
function UIAnimator.fadeIn(group: CanvasGroup): Tween
	return UIAnimator.tween(group, FADE_INFO, { GroupTransparency = 0 })
end

-- ค่อยๆ ซ่อน CanvasGroup จนใสสนิท ใช้เวลาเท่ากับ fadeIn (ไม่ปิด Visible ให้ ผู้เรียกจัดการเอง)
function UIAnimator.fadeOut(group: CanvasGroup): Tween
	return UIAnimator.tween(group, FADE_INFO, { GroupTransparency = 1 })
end

return table.freeze(UIAnimator)
