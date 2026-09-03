--!strict
-- PSU.luau — แคตตาล็อกพาวเวอร์ซัพพลาย 5 รุ่น
-- ตัว PSU ไม่ได้ "กิน" ไฟ แต่เป็นตัวจ่ายไฟ จึงใส่ watt = 0 เสมอ แล้วไปดู wattOutput แทน
--
-- คำนวณจากแคตตาล็อกที่มีอยู่ ณ ตอนสร้างไฟล์นี้:
--   worst case แบบ max ทุกหมวด (ไม่สนความเข้ากันได้) = 170+65+320+14+9 = 578W -> x1.2 = 694W
--   worst case ที่ประกอบได้จริง (9950X + B650 + RTX 4080S + 64GB + Gen5) = 561W -> x1.2 = 674W
-- ใช้ตัวเลข 694W เป็นเกณฑ์ (เผื่อไว้มากกว่า) -> psu_750w และ psu_850w รองรับได้
-- ถ้าเพิ่มชิ้นส่วนที่กินไฟมากขึ้นในอนาคต ต้องกลับมาคิด worst case ใหม่ที่นี่
--
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local PSUs: { Types.PSU } = {
	-- tier 1 — พอสำหรับเครื่องออฟฟิศที่ไม่มีการ์ดจอแยก หรือการ์ดจอที่ไม่ต้องต่อไฟเลี้ยง
	{
		id = "psu_450w_std",
		name = "Cooler Master Elite V4 450W",
		category = "PSU",
		price = 1090,
		watt = 0,
		perfScore = 12,
		tier = 1,
		wattOutput = 450,
		efficiency = "80+",
		isModular = false,
	},

	-- tier 2 — เครื่องเกมระดับเริ่มต้น
	{
		id = "psu_550w_bronze",
		name = "Antec CSK 550W 80+ Bronze",
		category = "PSU",
		price = 1590,
		watt = 0,
		perfScore = 30,
		tier = 2,
		wattOutput = 550,
		efficiency = "80+ Bronze",
		isModular = false,
	},

	-- tier 3 — ตัวยอดนิยม รองรับการ์ดจอระดับกลางได้สบาย
	{
		id = "psu_650w_bronze",
		name = "Corsair CV650 80+ Bronze",
		category = "PSU",
		price = 2290,
		watt = 0,
		perfScore = 48,
		tier = 3,
		wattOutput = 650,
		efficiency = "80+ Bronze",
		isModular = false,
	},

	-- tier 4 — รองรับ worst case ของแคตตาล็อกนี้ได้ (694W) และเป็นโมดูลาร์ตัวแรก
	{
		id = "psu_750w_gold",
		name = "MSI MAG A750GL 80+ Gold",
		category = "PSU",
		price = 3290,
		watt = 0,
		perfScore = 70,
		tier = 4,
		wattOutput = 750,
		efficiency = "80+ Gold",
		isModular = true,
	},

	-- tier 5 — เผื่อหัวไว้เยอะ ประสิทธิภาพการแปลงไฟสูงสุด
	{
		id = "psu_850w_platinum",
		name = "Seasonic PRIME PX-850 80+ Platinum",
		category = "PSU",
		price = 6990,
		watt = 0,
		perfScore = 90,
		tier = 5,
		wattOutput = 850,
		efficiency = "80+ Platinum",
		isModular = true,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, psu in PSUs do
	table.freeze(psu)
end

return table.freeze(PSUs)
