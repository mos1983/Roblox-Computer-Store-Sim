--!strict
-- RAM.luau — แคตตาล็อกแรม 6 รุ่น (DDR4 3 รุ่น / DDR5 3 รุ่น)
-- ทุกรุ่นต้องมีเมนบอร์ดใน Mainboard.luau รองรับได้จริง ทั้ง ramType, ramSlots และ maxRamGB
-- หมายเหตุ: ตอนนี้มีบอร์ด DDR4 แค่รุ่นเดียว (mb_h610m_ddr4, 2 สล็อต, สูงสุด 64GB)
-- ชุด DDR4 จึงต้องเป็นแบบ 2 แถวและไม่เกิน 64GB เท่านั้น
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local RAMs: { Types.RAM } = {
	-- tier 1 — ความจุขั้นต่ำสำหรับงานเอกสาร
	{
		id = "ram_ddr4_8gb_3200",
		name = "Kingston FURY Beast DDR4 8GB (2x4GB) 3200",
		category = "RAM",
		price = 690,
		watt = 5,
		perfScore = 10,
		tier = 1,
		ramType = "DDR4",
		sizeGB = 8,
		sticks = 2,
		speedMHz = 3200,
	},
	{
		id = "ram_ddr4_16gb_3200",
		name = "Kingston FURY Beast DDR4 16GB (2x8GB) 3200",
		category = "RAM",
		price = 1190,
		watt = 7,
		perfScore = 18,
		tier = 1,
		ramType = "DDR4",
		sizeGB = 16,
		sticks = 2,
		speedMHz = 3200,
	},

	-- tier 2 — 16GB ยุคใหม่ เร็วกว่าเดิมแต่ความจุเท่ากัน
	{
		id = "ram_ddr5_16gb_5600",
		name = "Corsair Vengeance DDR5 16GB (2x8GB) 5600",
		category = "RAM",
		price = 1890,
		watt = 8,
		perfScore = 28,
		tier = 2,
		ramType = "DDR5",
		sizeGB = 16,
		sticks = 2,
		speedMHz = 5600,
	},

	-- tier 3 — 32GB สายทำงาน ยังใช้แพลตฟอร์มเดิมได้
	{
		id = "ram_ddr4_32gb_3600",
		name = "G.SKILL Ripjaws V DDR4 32GB (2x16GB) 3600",
		category = "RAM",
		price = 2390,
		watt = 9,
		perfScore = 42,
		tier = 3,
		ramType = "DDR4",
		sizeGB = 32,
		sticks = 2,
		speedMHz = 3600,
	},

	-- tier 4 — 32GB DDR5 สำหรับเกม/ตัดต่อจริงจัง
	{
		id = "ram_ddr5_32gb_6000",
		name = "G.SKILL Trident Z5 DDR5 32GB (2x16GB) 6000",
		category = "RAM",
		price = 3690,
		watt = 10,
		perfScore = 62,
		tier = 4,
		ramType = "DDR5",
		sizeGB = 32,
		sticks = 2,
		speedMHz = 6000,
	},

	-- tier 5 — 64GB สายเวิร์กสเตชัน ใช้ครบ 4 แถว ต้องเป็นบอร์ด 4 สล็อตเท่านั้น
	{
		id = "ram_ddr5_64gb_6000",
		name = "Corsair Vengeance DDR5 64GB (4x16GB) 6000",
		category = "RAM",
		price = 7290,
		watt = 14,
		perfScore = 88,
		tier = 5,
		ramType = "DDR5",
		sizeGB = 64,
		sticks = 4,
		speedMHz = 6000,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, ram in RAMs do
	table.freeze(ram)
end

return table.freeze(RAMs)
