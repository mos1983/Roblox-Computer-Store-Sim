--!strict
-- Enums.luau — ค่าคงที่กลางที่ใช้ร่วมกันทั้งฝั่ง server และ client
-- เก็บเป็น string literal เพื่อให้ส่งผ่าน RemoteEvent และเทียบค่าตรง ๆ ได้

export type Socket = "AM5" | "AM4" | "LGA1700"
export type RamType = "DDR4" | "DDR5"
export type FormFactor = "ATX" | "mATX" | "Mini-ITX"

-- 7 หมวดของชิ้นส่วนที่ผู้เล่นต้องประกอบ
export type Category = "CPU" | "Mainboard" | "RAM" | "GPU" | "Storage" | "PSU" | "Case"

-- enum เสริมที่ field เฉพาะหมวดต้องใช้
export type StorageKind = "HDD" | "SATA_SSD" | "NVMe"
export type PsuEfficiency = "80+" | "80+ Bronze" | "80+ Gold" | "80+ Platinum"

local Enums = {
	Socket = table.freeze({
		AM5 = "AM5" :: Socket,
		AM4 = "AM4" :: Socket,
		LGA1700 = "LGA1700" :: Socket,
	}),

	RamType = table.freeze({
		DDR4 = "DDR4" :: RamType,
		DDR5 = "DDR5" :: RamType,
	}),

	FormFactor = table.freeze({
		ATX = "ATX" :: FormFactor,
		MATX = "mATX" :: FormFactor,
		MiniITX = "Mini-ITX" :: FormFactor,
	}),

	Category = table.freeze({
		CPU = "CPU" :: Category,
		Mainboard = "Mainboard" :: Category,
		RAM = "RAM" :: Category,
		GPU = "GPU" :: Category,
		Storage = "Storage" :: Category,
		PSU = "PSU" :: Category,
		Case = "Case" :: Category,
	}),

	StorageKind = table.freeze({
		HDD = "HDD" :: StorageKind,
		SataSSD = "SATA_SSD" :: StorageKind,
		NVMe = "NVMe" :: StorageKind,
	}),

	PsuEfficiency = table.freeze({
		Standard = "80+" :: PsuEfficiency,
		Bronze = "80+ Bronze" :: PsuEfficiency,
		Gold = "80+ Gold" :: PsuEfficiency,
		Platinum = "80+ Platinum" :: PsuEfficiency,
	}),

	-- ลิสต์แบบเรียงลำดับ ใช้ตอน loop สร้าง UI หรือสุ่มโจทย์ (ลำดับคงที่เสมอ)
	SocketList = table.freeze({ "AM5", "AM4", "LGA1700" } :: { Socket }),
	RamTypeList = table.freeze({ "DDR4", "DDR5" } :: { RamType }),
	FormFactorList = table.freeze({ "ATX", "mATX", "Mini-ITX" } :: { FormFactor }),
	CategoryList = table.freeze({
		"CPU", "Mainboard", "RAM", "GPU", "Storage", "PSU", "Case",
	} :: { Category }),

	-- ขอบเขตค่าตัวเลขที่ใช้ตรวจความถูกต้องของข้อมูลชิ้นส่วน
	MIN_PERF_SCORE = 0,
	MAX_PERF_SCORE = 100,
	MIN_TIER = 1,
	MAX_TIER = 5,
}

return table.freeze(Enums)
