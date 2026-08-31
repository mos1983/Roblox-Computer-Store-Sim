--!strict
-- CPU.luau — แคตตาล็อกซีพียู 9 รุ่น (AM5 5 รุ่น / LGA1700 4 รุ่น)
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local CPUs: { Types.CPU } = {
	-- tier 1 — เครื่องสำนักงาน/งานเอกสาร
	{
		id = "cpu_celeron_g6900",
		name = "Intel Celeron G6900",
		category = "CPU",
		price = 1690,
		watt = 46,
		perfScore = 12,
		tier = 1,
		socket = "LGA1700",
		cores = 2,
		threads = 2,
		boostClockGHz = 3.4,
		hasIGPU = true,
	},

	-- tier 2 — งานทั่วไป/เกมเบา ๆ
	{
		id = "cpu_i3_12100f",
		name = "Intel Core i3-12100F",
		category = "CPU",
		price = 2690,
		watt = 58,
		perfScore = 32,
		tier = 2,
		socket = "LGA1700",
		cores = 4,
		threads = 8,
		boostClockGHz = 4.3,
		hasIGPU = false, -- รหัส F ไม่มีการ์ดจอในตัว ต้องใส่ GPU แยก
	},
	{
		id = "cpu_r5_7500f",
		name = "AMD Ryzen 5 7500F",
		category = "CPU",
		price = 5190,
		watt = 65,
		perfScore = 38,
		tier = 2,
		socket = "AM5",
		cores = 6,
		threads = 12,
		boostClockGHz = 5.0,
		hasIGPU = false,
	},

	-- tier 3 — เกมมิ่งระดับเริ่มต้นถึงกลาง
	{
		id = "cpu_i5_12400f",
		name = "Intel Core i5-12400F",
		category = "CPU",
		price = 4290,
		watt = 65,
		perfScore = 45,
		tier = 3,
		socket = "LGA1700",
		cores = 6,
		threads = 12,
		boostClockGHz = 4.4,
		hasIGPU = false,
	},
	{
		id = "cpu_r5_7600",
		name = "AMD Ryzen 5 7600",
		category = "CPU",
		price = 7090,
		watt = 65,
		perfScore = 52,
		tier = 3,
		socket = "AM5",
		cores = 6,
		threads = 12,
		boostClockGHz = 5.1,
		hasIGPU = true,
	},

	-- tier 4 — เกมมิ่งจริงจัง/ตัดต่อ
	{
		id = "cpu_i5_14600kf",
		name = "Intel Core i5-14600KF",
		category = "CPU",
		price = 9590,
		watt = 125,
		perfScore = 72,
		tier = 4,
		socket = "LGA1700",
		cores = 14, -- 6 P-core + 8 E-core
		threads = 20,
		boostClockGHz = 5.3,
		hasIGPU = false,
	},
	{
		id = "cpu_r7_9700x",
		name = "AMD Ryzen 7 9700X",
		category = "CPU",
		price = 12900,
		watt = 65,
		perfScore = 76,
		tier = 4,
		socket = "AM5",
		cores = 8,
		threads = 16,
		boostClockGHz = 5.5,
		hasIGPU = true,
	},

	-- tier 5 — เรือธง
	{
		id = "cpu_r7_9800x3d",
		name = "AMD Ryzen 7 9800X3D",
		category = "CPU",
		price = 19900,
		watt = 120,
		perfScore = 92,
		tier = 5,
		socket = "AM5",
		cores = 8,
		threads = 16,
		boostClockGHz = 5.2,
		hasIGPU = true,
	},
	{
		id = "cpu_r9_9950x",
		name = "AMD Ryzen 9 9950X",
		category = "CPU",
		price = 22900,
		watt = 170,
		perfScore = 97,
		tier = 5,
		socket = "AM5",
		cores = 16,
		threads = 32,
		boostClockGHz = 5.7,
		hasIGPU = true,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, cpu in CPUs do
	table.freeze(cpu)
end

return table.freeze(CPUs)
