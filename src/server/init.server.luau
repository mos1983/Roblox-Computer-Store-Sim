--!strict
--[[
	init.server.luau — จุดเริ่มต้นฝั่ง server (Script ตัวเดียว ไฟล์อื่นใน src/server เป็น ModuleScript)
	แต่ละระบบห่อ pcall แยกกัน ตัวไหนพังจะ warn แล้วตัวที่เหลือยังทำงานต่อได้
]]

local NPCService = require(script.Systems.NPCService)

local function start(systemName: string, init: () -> ()): ()
	local ok, message = pcall(init)
	if not ok then
		warn(`[Server] เริ่ม {systemName} ไม่สำเร็จ: {message}`)
	end
end

start("NPCService", NPCService.init)
