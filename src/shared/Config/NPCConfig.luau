--!strict
-- NPCConfig.luau — ค่าปรับสมดุลของระบบ NPC (spawn / เดิน / dialogue)
-- แยกออกมาเป็นไฟล์เดียวเพื่อให้ปรับจังหวะเกมได้โดยไม่ต้องแตะ logic
-- freeze ไว้กันเผลอแก้ค่าตอน runtime

--[[
	ลำดับของลูกค้า 1 คน (เส้นทางอยู่ใน Workspace.NPCs.MainNPCs.MainNPCsPath)
		ร้าน Idle ครบ SPAWN_INTERVAL → spawn ที่ Checkpoint1 (ตำแหน่งและทิศเดียวกับ part)
		→ เดินไป Checkpoint2_1 → หยุด PAUSE_AT_CP2_1 → ก้าวเข้าเคาน์เตอร์ที่ Checkpoint2_2
		→ รอ DIALOGUE_DELAY → dialogue ขึ้นทีละท่อน (กด Continue ไปท่อนถัดไป)
		→ กด Continue ท่อนสุดท้าย → รอ LEAVE_DELAY → เดินกลับ Checkpoint1 → ลบ model → ร้านกลับเป็น Idle
	ก่อนเดินแต่ละช่วงจะหันไปทางจุดหมายอยู่กับที่ก่อน (TURN_SPEED) ถึง Checkpoint2_2 แล้วหันตามหน้าของ part

	เวลาทุกค่าเป็นวินาที ไม่มีการสุ่ม
	ความเร็วเดินคงที่ จังหวะเดินจึงขึ้นกับระยะ: ช่วง Checkpoint2_1 → 2_2 ต้องสั้นกว่า Checkpoint1 → 2_1 (จัดใน Studio)
]]
export type NPCConfig = {
	SPAWN_INTERVAL: number,
	WALK_SPEED: number,
	TURN_SPEED: number,
	DIALOGUE_DELAY: number,
	LEAVE_DELAY: number,
	PAUSE_AT_CP2_1: number,
}

local NPCConfig: NPCConfig = table.freeze({
	SPAWN_INTERVAL = 5, -- หลังผู้เล่นกด Play หรือหลังร้านกลับเป็น Idle (NPC ตัวก่อนหายไป)
	WALK_SPEED = 10, -- studs ต่อวินาที
	TURN_SPEED = 540, -- องศาต่อวินาที (หันกลับหลัง 180° ใช้ 1/3 วินาที)
	DIALOGUE_DELAY = 1.5, -- หน่วงหลังถึงเคาน์เตอร์ก่อนเด้ง dialogue
	LEAVE_DELAY = 0.3, -- หน่วงหลังกด Continue ท่อนสุดท้ายก่อนเดินออก
	PAUSE_AT_CP2_1 = 0.2, -- หยุดแวะสั้นๆ ที่ Checkpoint2_1 ก่อนก้าวเข้าเคาน์เตอร์
})

return NPCConfig
