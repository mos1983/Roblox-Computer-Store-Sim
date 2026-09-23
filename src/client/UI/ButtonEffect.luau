--!strict
--[[
	ButtonEffect.luau — เอฟเฟกต์ตอนเคอร์เซอร์ชี้/กดปุ่ม ใช้ได้กับ GuiButton ทุกตัว
	ชี้แล้วขยายเล็กน้อย กดแล้วหด ผ่าน UIScale (ไม่แตะ Size/Position ที่ออกแบบไว้ใน Studio)
	ปุ่มจะขยายโดยยึด AnchorPoint ถ้าอยากให้ขยายจากกึ่งกลาง ให้ตั้ง AnchorPoint ของปุ่มเป็น 0.5, 0.5

	UIController ใส่ให้ทุกปุ่มใน Title และ GUI อัตโนมัติ
	ปุ่มไหนไม่อยากได้เอฟเฟกต์ ให้ใส่ Attribute "NoButtonEffect" = true ที่ปุ่มใน Studio

	ใช้ InputBegan/InputEnded ของปุ่มแทน MouseEnter/MouseLeave
	เพราะ MouseLeave มักไม่ยิงตอนเลื่อนเมาส์เร็วๆ และแบบนี้รองรับการแตะบนจอสัมผัสไปในตัว
]]

local UIAnimator = require(script.Parent.UIAnimator)

local HOVER_SCALE: number = 1.06
local PRESS_SCALE: number = 0.94
local REST_SCALE: number = 1
local OPT_OUT_ATTRIBUTE: string = "NoButtonEffect"

type ButtonState = {
	hovered: boolean,
	pressed: boolean,
}

-- weak key: ปุ่มที่ถูกลบไปแล้ว (เช่นรายการที่สร้างใหม่ทุกรอบ) จะหลุดออกจากตารางเอง
local states: { [GuiButton]: ButtonState } = setmetatable({}, { __mode = "k" }) :: any

local ButtonEffect = {}

local function refresh(button: GuiButton, state: ButtonState): ()
	local factor = if state.pressed then PRESS_SCALE elseif state.hovered then HOVER_SCALE else REST_SCALE
	UIAnimator.scaleTo(button, factor)
end

local function isPress(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

-- ใส่เอฟเฟกต์ให้ปุ่ม เรียกซ้ำกับปุ่มเดิมได้ ไม่ซ้อนกัน
function ButtonEffect.apply(button: GuiButton): ()
	if states[button] ~= nil or button:GetAttribute(OPT_OUT_ATTRIBUTE) == true then
		return
	end

	local state: ButtonState = { hovered = false, pressed = false }
	states[button] = state

	button.InputBegan:Connect(function(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			state.hovered = true
		elseif isPress(input.UserInputType) then
			state.pressed = true
		else
			return
		end
		refresh(button, state)
	end)

	button.InputEnded:Connect(function(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- เคอร์เซอร์ออกนอกปุ่ม นับว่าปล่อยปุ่มด้วย (กันกรณีกดค้างแล้วลากออก)
			state.hovered = false
			state.pressed = false
		elseif isPress(input.UserInputType) then
			state.pressed = false
		else
			return
		end
		refresh(button, state)
	end)
end

--[[
	คืนปุ่มทุกตัวใน container กลับขนาดปกติ — UIController เรียกตอนซ่อนหน้าจอ
	ถ้าปุ่มหายไปขณะเคอร์เซอร์ยังชี้อยู่ Roblox อาจไม่ยิง InputEnded ให้
	ปุ่มจะค้างขนาด hover ไว้จนกว่าจะกลับมาหน้านั้นอีกรอบ
]]
function ButtonEffect.resetWithin(container: Instance): ()
	for button, state in states do
		if (state.hovered or state.pressed) and button:IsDescendantOf(container) then
			state.hovered = false
			state.pressed = false
			refresh(button, state)
		end
	end
end

return table.freeze(ButtonEffect)
