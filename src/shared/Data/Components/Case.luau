--!strict
-- Case.luau — แคตตาล็อกเคส 4 รุ่น
-- เคสไม่กินไฟ ใส่ watt = 0 เสมอ
--
-- กฎการรองรับเมนบอร์ด: เคสใหญ่ใส่บอร์ดเล็กกว่าได้เสมอ (แต่กลับกันไม่ได้)
--   เคส ATX      -> ATX, mATX, Mini-ITX (3 ขนาด)
--   เคส mATX     -> mATX, Mini-ITX (2 ขนาด)
--   เคส Mini-ITX -> Mini-ITX อย่างเดียว
--
-- GPU ที่ยาวที่สุดในแคตตาล็อกคือ RTX 4080 SUPER 330mm
-- -> case_atx_mid (340mm) และ case_atx_full (400mm) ใส่ได้ ที่เหลือใส่ไม่ได้
-- ถ้าเพิ่มการ์ดจอที่ยาวกว่านี้ ต้องกลับมาเช็ค maxGpuLengthMM ที่นี่
--
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local Cases: { Types.Case } = {
	-- tier 1 — เคส mATX ราคาประหยัด ตัวเลือกเริ่มต้นของเครื่องออฟฟิศ
	{
		id = "case_matx_budget",
		name = "Tsunami Halo M1 (mATX)",
		category = "Case",
		price = 1190,
		watt = 0,
		perfScore = 14,
		tier = 1,
		supportedFormFactors = { "mATX", "Mini-ITX" },
		maxGpuLengthMM = 320,
		fanSlots = 3,
	},

	-- tier 2 — เคส ATX มิดทาวเวอร์ ใส่ได้ทุกอย่างรวมถึงการ์ดจอที่ยาวที่สุด
	{
		id = "case_atx_mid",
		name = "NZXT H5 Flow (ATX Mid Tower)",
		category = "Case",
		price = 2490,
		watt = 0,
		perfScore = 34,
		tier = 2,
		supportedFormFactors = { "ATX", "mATX", "Mini-ITX" },
		maxGpuLengthMM = 340,
		fanSlots = 4,
	},

	-- tier 3 — เคส Mini-ITX ทรงเล็ก จ่ายแพงขึ้นเพื่อขนาดที่เล็กลง แลกกับพื้นที่การ์ดจอ
	{
		id = "case_itx_sff",
		name = "Cooler Master NR200P (Mini-ITX SFF)",
		category = "Case",
		price = 3290,
		watt = 0,
		perfScore = 52,
		tier = 3,
		supportedFormFactors = { "Mini-ITX" },
		maxGpuLengthMM = 285, -- เคสเล็กใส่การ์ดเรือธง 330mm ไม่ได้
		fanSlots = 2,
	},

	-- tier 4 — ฟูลทาวเวอร์ ระบายความร้อนดีที่สุด พื้นที่เหลือเฟือ
	{
		id = "case_atx_full",
		name = "Lian Li LANCOOL III (ATX Full Tower)",
		category = "Case",
		price = 4590,
		watt = 0,
		perfScore = 74,
		tier = 4,
		supportedFormFactors = { "ATX", "mATX", "Mini-ITX" },
		maxGpuLengthMM = 400,
		fanSlots = 7,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, case in Cases do
	table.freeze(case.supportedFormFactors) -- freeze array ข้างในด้วย เพราะ table.freeze เป็นแบบตื้น
	table.freeze(case)
end

return table.freeze(Cases)
