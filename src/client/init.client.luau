--!strict
--[[
	init.client.luau — จุดเริ่มต้นฝั่ง client (LocalScript ตัวเดียวของเกม ไฟล์อื่นเป็น ModuleScript ทั้งหมด)

	เริ่มระบบตามลำดับ กล้อง → คลิกวัตถุ 3D → UI
	UI ต้องมาหลังสุด เพราะตอนเริ่มจะสั่งกล้องและ InteractionService ให้เข้าสถานะของหน้า Title
	แต่ละระบบห่อ pcall แยกกัน ตัวไหนพังจะ warn แล้วตัวที่เหลือยังทำงานต่อได้
]]

local CameraController = require(script.Camera.CameraController)
local InteractionService = require(script.Interaction.InteractionService)
local UIController = require(script.UI.UIController)

local function start(systemName: string, init: () -> ()): ()
	local ok, message = pcall(init)
	if not ok then
		warn(`[Client] เริ่ม {systemName} ไม่สำเร็จ: {message}`)
	end
end

start("CameraController", CameraController.init)
start("InteractionService", InteractionService.init)
start("UIController", UIController.init)
