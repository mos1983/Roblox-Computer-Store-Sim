--!strict
-- NPCTypes.luau — type กลางของระบบ NPC (spawn / เดิน / dialogue)
-- แยกจาก Types.luau ที่เก็บเฉพาะชิ้นส่วนคอมพิวเตอร์ 7 หมวด

--[[
	สถานะร้าน ("Store State" ในเอกสาร)
	- Idle   : ไม่มีลูกค้าในร้าน ("Not In Queue") ครบ NPCConfig.SPAWN_INTERVAL แล้ว spawn ตัวใหม่
	- Queued : มีลูกค้าอยู่ในร้าน ("In Queue") ห้าม spawn เพิ่มจนกว่าตัวเดิมจะถูกลบ
]]
export type StoreState = "Idle" | "Queued"

--[[
	ข้อมูลที่ server ส่งให้ client แสดงใน GUI.Main.Dialogue (ส่งไป client ได้ตามกฎใน CLAUDE.md)
	ไม่มี targetSpec — ระดับ Easy บอกชื่อรุ่นชิ้นส่วนในข้อความ ซึ่งตั้งใจไว้ตั้งแต่ RequestDialogue แล้ว

	info เป็นท่อนข้อความเรียงตามลำดับที่ต้องแสดง:
		Greetings → Intents → Details → (IntegratedGpuNote เฉพาะโจทย์ที่ใช้การ์ดจอออนบอร์ด) → BudgetPhrases
	GUI แสดงทีละท่อนใน Dialogue.Info กด ContinueButton ไปท่อนถัดไป
	กดท่อนสุดท้ายแล้ว NPC จึงเดินกลับ Checkpoint1
]]
export type DialoguePayload = {
	npcId: string,
	npcType: string, -- แสดงใน Dialogue.NpcType เช่น "CUSTOMER"
	info: { string }, -- ท่อนข้อความจาก RequestDialogue เรียงตามลำดับการแสดง
}

return {}
