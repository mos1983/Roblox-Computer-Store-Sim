--!strict
--[[
	SafeFind.luau — หา instance ตาม path แบบไม่ทำให้ระบบอื่นพัง

	GUI และ Workspace ของเกมอยู่บน Roblox cloud ไม่มีในไฟล์บนดิสก์ ชื่อจึงอาจถูกเปลี่ยนใน Studio ได้ทุกเมื่อ
	ทุกระบบฝั่ง client หา instance ผ่านไฟล์นี้: ถ้าหาไม่เจอจะ warn path เต็มแล้วคืน nil
	ผู้เรียกเช็ค nil แล้วข้ามเฉพาะส่วนนั้น ส่วนอื่นของเกมยังทำงานต่อได้

	ใช้งาน:
		local play = SafeFind.path(playerGui, "Title.Buttons.Play", "GuiButton") :: GuiButton?
		if play ~= nil then ... end
]]

local DEFAULT_TIMEOUT: number = 10 -- วินาที เผื่อ GUI เพิ่ง clone เข้า PlayerGui หรือ part ใน Workspace ยังโหลดไม่เสร็จ

local SafeFind = {}

-- ชื่อเต็มแบบเดียวกับที่จดไว้ใน CLAUDE.md เช่น "PlayerGui.GUI.Main" (ตัด "Players.<ชื่อผู้เล่น>." ข้างหน้าออก)
function SafeFind.describe(instance: Instance): string
	local fullName = instance:GetFullName()
	return string.match(fullName, "^Players%.[^%.]+%.(.+)$") or fullName
end

--[[
	หา instance จาก path คั่นด้วยจุด ไล่ลงทีละชั้นจาก root
	- แต่ละชั้นรอได้ไม่เกิน timeout วินาที (ไม่ใส่ = DEFAULT_TIMEOUT)
	- ใส่ className มาด้วยจะเช็ค IsA ให้ กันเจอของชื่อตรงแต่ชนิดผิด
	- หาไม่เจอหรือชนิดไม่ตรง: warn path เต็มแล้วคืน nil
]]
function SafeFind.path(root: Instance, path: string, className: string?, timeout: number?): Instance?
	local current = root
	for _, name in string.split(path, ".") do
		local child = current:WaitForChild(name, timeout or DEFAULT_TIMEOUT)
		if child == nil then
			warn(`[SafeFind] หา {SafeFind.describe(root)}.{path} ไม่เจอ (ไม่มี "{name}" ใน {SafeFind.describe(current)}) ข้ามส่วนที่ใช้ instance นี้`)
			return nil
		end
		current = child
	end

	if className ~= nil and not current:IsA(className) then
		warn(`[SafeFind] {SafeFind.describe(current)} เป็น {current.ClassName} ไม่ใช่ {className} ข้ามส่วนที่ใช้ instance นี้`)
		return nil
	end

	return current
end

return table.freeze(SafeFind)
