--!strict
-- Mainboard.luau — แคตตาล็อกเมนบอร์ด 6 รุ่น (AM5 3 รุ่น / LGA1700 3 รุ่น)
-- socket ต้องครอบคลุมทุกค่าที่มีใน CPU.luau และมีอย่างน้อย 2 รุ่นต่อ socket
-- เพื่อให้ผู้เล่นมีทางเลือกเสมอ ไม่ว่าโจทย์จะบังคับซีพียูตัวไหน
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local Mainboards: { Types.Mainboard } = {
	-- tier 1 — บอร์ดพื้นฐาน คู่กับซีพียูออฟฟิศ
	{
		id = "mb_h610m_ddr4",
		name = "ASUS PRIME H610M-K D4",
		category = "Mainboard",
		price = 2290,
		watt = 30,
		perfScore = 10,
		tier = 1,
		socket = "LGA1700",
		ramType = "DDR4", -- LGA1700 มีทั้งรุ่น DDR4 และ DDR5 ตัวนี้คือฝั่ง DDR4 ราคาประหยัด
		formFactor = "mATX",
		ramSlots = 2,
		maxRamGB = 64, -- DDR4 แถวละ 32GB × 2 แถว
		m2Slots = 1,
	},
	{
		id = "mb_a620m_ddr5",
		name = "ASUS PRIME A620M-K",
		category = "Mainboard",
		price = 2990,
		watt = 32,
		perfScore = 16,
		tier = 1,
		socket = "AM5",
		ramType = "DDR5", -- AM5 รองรับ DDR5 อย่างเดียว
		formFactor = "mATX",
		ramSlots = 2,
		maxRamGB = 96, -- DDR5 แถวละ 48GB × 2 แถว
		m2Slots = 1,
	},

	-- tier 2 — บอร์ดงานทั่วไป เริ่มมีสล็อตแรมครบ 4
	{
		id = "mb_b760m_ddr5",
		name = "MSI PRO B760M-A WIFI",
		category = "Mainboard",
		price = 4590,
		watt = 44,
		perfScore = 36,
		tier = 2,
		socket = "LGA1700",
		ramType = "DDR5",
		formFactor = "mATX",
		ramSlots = 4,
		maxRamGB = 192, -- DDR5 แถวละ 48GB × 4 แถว
		m2Slots = 2,
	},

	-- tier 3 — บอร์ดเกมมิ่งขนาดเต็ม อัปเกรดได้ยาว
	{
		id = "mb_b650_atx",
		name = "GIGABYTE B650 EAGLE AX",
		category = "Mainboard",
		price = 6490,
		watt = 48,
		perfScore = 55,
		tier = 3,
		socket = "AM5",
		ramType = "DDR5",
		formFactor = "ATX",
		ramSlots = 4,
		maxRamGB = 192,
		m2Slots = 3,
	},

	-- tier 4 — บอร์ดเล็กสเปกสูง สำหรับเครื่องคอมแพ็ก
	{
		id = "mb_b650i_itx",
		name = "ASRock B650I Lightning WiFi",
		category = "Mainboard",
		price = 9290,
		watt = 42,
		perfScore = 68,
		tier = 4,
		socket = "AM5",
		ramType = "DDR5",
		formFactor = "Mini-ITX",
		ramSlots = 2, -- Mini-ITX มีที่ว่างแค่ 2 แถวเสมอ
		maxRamGB = 96,
		m2Slots = 2,
	},

	-- tier 5 — เรือธง ไฟเลี้ยงแน่น รองรับซีพียูรหัส K
	{
		id = "mb_z790_atx",
		name = "MSI MAG Z790 TOMAHAWK WIFI",
		category = "Mainboard",
		price = 11900,
		watt = 65,
		perfScore = 88,
		tier = 5,
		socket = "LGA1700",
		ramType = "DDR5",
		formFactor = "ATX",
		ramSlots = 4,
		maxRamGB = 192,
		m2Slots = 4,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, mainboard in Mainboards do
	table.freeze(mainboard)
end

return table.freeze(Mainboards)
