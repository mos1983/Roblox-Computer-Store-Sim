--!strict
-- GPU.luau — แคตตาล็อกการ์ดจอ 9 รุ่น ไล่ตั้งแต่การ์ดเริ่มต้นถึงเรือธง
-- perfScore ถูกจัดให้กระจายเต็มช่วง 0-100 แบบไม่มีช่องว่าง เพื่อให้โจทย์ทุกระดับ
-- หา "การ์ดที่พอดี" ได้เสมอ (ดูกฎ coverage ท้ายไฟล์)
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100
-- lengthMM เรียงตาม tier (การ์ดแรงกินพื้นที่มากกว่า) ใช้เทียบกับ maxGpuLengthMM ของเคส
-- recommendedPsuWatt = watt ของการ์ด + 200 ปัดขึ้นเป็นขนาด PSU ที่มีขายจริง (ทีละ 50W)

local Types = require(script.Parent.Parent.Parent.Types)

local GPUs: { Types.GPU } = {
	-- tier 1 — การ์ดเสียบเสริมสำหรับเครื่องออฟฟิศ/เกมเก่า ไม่ต้องต่อไฟเลี้ยงเพิ่ม
	{
		id = "gpu_gtx_1650",
		name = "NVIDIA GeForce GTX 1650",
		category = "GPU",
		price = 3790,
		watt = 75,
		perfScore = 10,
		tier = 1,
		vramGB = 4,
		lengthMM = 176,
		recommendedPsuWatt = 300,
	},
	{
		id = "gpu_arc_a380",
		name = "Intel Arc A380",
		category = "GPU",
		price = 4590,
		watt = 75,
		perfScore = 18,
		tier = 1,
		vramGB = 6,
		lengthMM = 190,
		recommendedPsuWatt = 300,
	},

	-- tier 2 — เกม 1080p ตั้งค่าปานกลาง
	{
		id = "gpu_rx_6500xt",
		name = "AMD Radeon RX 6500 XT 8GB",
		category = "GPU",
		price = 5590,
		watt = 107,
		perfScore = 28,
		tier = 2,
		vramGB = 8,
		lengthMM = 200,
		recommendedPsuWatt = 350,
	},
	{
		id = "gpu_rx_6600",
		name = "AMD Radeon RX 6600",
		category = "GPU",
		price = 7290,
		watt = 132,
		perfScore = 38,
		tier = 2,
		vramGB = 8,
		lengthMM = 205,
		recommendedPsuWatt = 350,
	},

	-- tier 3 — เกม 1080p สูง ถึง 1440p
	{
		id = "gpu_arc_b580",
		name = "Intel Arc B580",
		category = "GPU",
		price = 10900,
		watt = 190,
		perfScore = 48,
		tier = 3,
		vramGB = 12,
		lengthMM = 272,
		recommendedPsuWatt = 400,
	},
	{
		id = "gpu_rx_7700xt",
		name = "AMD Radeon RX 7700 XT",
		category = "GPU",
		price = 14900,
		watt = 245,
		perfScore = 60,
		tier = 3,
		vramGB = 12,
		lengthMM = 276,
		recommendedPsuWatt = 450,
	},

	-- tier 4 — เกม 1440p ลื่น ๆ / ตัดต่อจริงจัง
	{
		id = "gpu_rtx_5070",
		name = "NVIDIA GeForce RTX 5070",
		category = "GPU",
		price = 19900,
		watt = 263,
		perfScore = 72,
		tier = 4,
		vramGB = 12,
		lengthMM = 287,
		recommendedPsuWatt = 500,
	},
	{
		id = "gpu_rtx_5070ti",
		name = "NVIDIA GeForce RTX 5070 Ti",
		category = "GPU",
		price = 28900,
		watt = 300,
		perfScore = 80,
		tier = 4,
		vramGB = 16,
		lengthMM = 300,
		recommendedPsuWatt = 500,
	},

	-- tier 5 — เรือธง เกม 4K การ์ดยาวเต็มพิกัด ต้องเลือกเคสให้ดี
	{
		id = "gpu_rtx_4080s",
		name = "NVIDIA GeForce RTX 4080 SUPER",
		category = "GPU",
		price = 42900,
		watt = 320,
		perfScore = 96,
		tier = 5,
		vramGB = 16,
		lengthMM = 330,
		recommendedPsuWatt = 550,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, gpu in GPUs do
	table.freeze(gpu)
end

return table.freeze(GPUs)
