--!strict
-- Storage.luau — แคตตาล็อกที่เก็บข้อมูล 6 รุ่น ครบทั้ง HDD / SATA_SSD / NVMe
-- แกนหลักที่ผู้เล่นต้องเรียนรู้: HDD ถูกและจุเยอะแต่ช้ามาก, NVMe เร็วสุดแต่แพงต่อ GB
-- readSpeedMBps อิงความเร็วจริงตามชนิด: HDD 150-190, SATA_SSD ~550 (ชนกำแพง SATA III), NVMe 3500-7000
-- ราคาเป็นบาท อ้างอิงราคาตลาดไทยโดยประมาณ (JIB/Advice) ไว้ปรับได้ที่นี่ที่เดียว
-- perfScore ต้องอยู่ในช่วงของ tier: t1=0-20, t2=21-40, t3=41-60, t4=61-80, t5=81-100

local Types = require(script.Parent.Parent.Parent.Types)

local Storages: { Types.Storage } = {
	-- tier 1 — จานหมุน ช้าที่สุดแต่ได้ความจุต่อบาทดีที่สุด
	{
		id = "sto_hdd_2tb",
		name = "Seagate BarraCuda 2TB 7200RPM",
		category = "Storage",
		price = 1690,
		watt = 6, -- มอเตอร์จานหมุนกินไฟมากกว่า SSD
		perfScore = 12,
		tier = 1,
		storageKind = "HDD",
		sizeGB = 2000,
		readSpeedMBps = 150,
	},

	{
		id = "sto_hdd_4tb",
		name = "Toshiba P300 4TB 7200RPM",
		category = "Storage",
		price = 3290,
		watt = 8, -- จานเยอะกว่า กินไฟมากกว่ารุ่น 2TB
		perfScore = 19,
		tier = 1,
		storageKind = "HDD",
		sizeGB = 4000,
		readSpeedMBps = 190, -- ความหนาแน่นข้อมูลต่อจานสูงกว่า อ่านต่อเนื่องได้เร็วกว่า 2TB
	},

	-- tier 2 — SSD ราคาประหยัด ใส่ระบบปฏิบัติการก็เร็วขึ้นชัดเจน
	{
		id = "sto_sata_480gb",
		name = "Kingston A400 480GB SATA SSD",
		category = "Storage",
		price = 990,
		watt = 3,
		perfScore = 28,
		tier = 2,
		storageKind = "SATA_SSD",
		sizeGB = 480,
		readSpeedMBps = 550,
	},

	-- tier 3 — SATA SSD ความจุ 1TB ชนเพดานความเร็วของอินเทอร์เฟซ SATA III
	{
		id = "sto_sata_1tb",
		name = "Crucial BX500 1TB SATA SSD",
		category = "Storage",
		price = 1990,
		watt = 4,
		perfScore = 43,
		tier = 3,
		storageKind = "SATA_SSD",
		sizeGB = 1000,
		readSpeedMBps = 560,
	},

	-- tier 4 — NVMe Gen4 มาตรฐานเครื่องเกมมิ่งยุคนี้
	{
		id = "sto_nvme_1tb_gen4",
		name = "WD Black SN770 1TB NVMe Gen4",
		category = "Storage",
		price = 2490,
		watt = 6,
		perfScore = 64,
		tier = 4,
		storageKind = "NVMe",
		sizeGB = 1000,
		readSpeedMBps = 5150,
	},

	-- tier 5 — NVMe Gen5 เร็วสุดในแคตตาล็อก สำหรับงานตัดต่อไฟล์ใหญ่
	{
		id = "sto_nvme_2tb_gen5",
		name = "Samsung 9100 PRO 2TB NVMe Gen5",
		category = "Storage",
		price = 6990,
		watt = 9,
		perfScore = 92,
		tier = 5,
		storageKind = "NVMe",
		sizeGB = 2000,
		readSpeedMBps = 7000,
	},
}

-- freeze รายชิ้นด้วย กันโค้ดฝั่งอื่นเผลอแก้ข้อมูลกลาง (table.freeze เป็นแบบตื้น)
for _, storage in Storages do
	table.freeze(storage)
end

return table.freeze(Storages)
