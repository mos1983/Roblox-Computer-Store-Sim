--!strict
-- Types.luau — type กลางของชิ้นส่วนคอมพิวเตอร์ทั้ง 7 หมวด
-- ใช้ร่วมกันระหว่าง Data (ข้อมูลสินค้า), Compatibility (ตรวจความเข้ากันได้) และ Scoring

local Enums = require(script.Parent.Data.Enums)

export type Socket = Enums.Socket
export type RamType = Enums.RamType
export type FormFactor = Enums.FormFactor
export type Category = Enums.Category
export type StorageKind = Enums.StorageKind
export type PsuEfficiency = Enums.PsuEfficiency

--[[
	field ร่วมที่ชิ้นส่วนทุกหมวดต้องมี
	- price   : ราคา (บาท) ใช้คิด BudgetScore
	- watt    : กำลังไฟที่ "กิน" (วัตต์) — PSU ให้ใส่ 0 แล้วไปดู wattOutput แทน
	- perfScore : คะแนนประสิทธิภาพ 0-100 ใช้คิด FitScore/BalanceScore
	- tier    : ระดับสินค้า 1-5 (1 = เริ่มต้น, 5 = เรือธง) ใช้จัดกลุ่มในร้าน
]]
export type PartBase = {
	id: string,
	name: string,
	category: Category,
	price: number,
	watt: number,
	perfScore: number,
	tier: number,
}

export type CPU = {
	id: string,
	name: string,
	category: "CPU",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	socket: Socket,
	cores: number,
	threads: number,
	boostClockGHz: number,
	hasIGPU: boolean, -- ถ้า true ใช้งานได้โดยไม่ต้องมีการ์ดจอแยก
}

export type Mainboard = {
	id: string,
	name: string,
	category: "Mainboard",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	socket: Socket,
	ramType: RamType,
	formFactor: FormFactor,
	ramSlots: number,
	maxRamGB: number,
	m2Slots: number,
}

export type RAM = {
	id: string,
	name: string,
	category: "RAM",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	ramType: RamType,
	sizeGB: number, -- ความจุรวมของชุด
	sticks: number, -- จำนวนแถว ต้องไม่เกิน ramSlots ของเมนบอร์ด
	speedMHz: number,
}

export type GPU = {
	id: string,
	name: string,
	category: "GPU",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	vramGB: number,
	lengthMM: number, -- ต้องไม่เกิน maxGpuLengthMM ของเคส
	recommendedPsuWatt: number,
}

export type Storage = {
	id: string,
	name: string,
	category: "Storage",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	storageKind: StorageKind,
	sizeGB: number,
	readSpeedMBps: number,
}

export type PSU = {
	id: string,
	name: string,
	category: "PSU",
	price: number,
	watt: number, -- ตัว PSU เองไม่กินไฟ ใส่ 0 เสมอ
	perfScore: number,
	tier: number,

	wattOutput: number, -- กำลังไฟที่จ่ายได้ ใช้เทียบกับผลรวม watt ของทั้งเครื่อง
	efficiency: PsuEfficiency,
	isModular: boolean,
}

export type Case = {
	id: string,
	name: string,
	category: "Case",
	price: number,
	watt: number,
	perfScore: number,
	tier: number,

	supportedFormFactors: { FormFactor }, -- เคส ATX รองรับเมนบอร์ดเล็กกว่าได้ด้วย
	maxGpuLengthMM: number,
	fanSlots: number,
}

-- union ของทุกหมวด แยกชนิดได้ด้วยการเช็ค part.category
export type AnyPart = CPU | Mainboard | RAM | GPU | Storage | PSU | Case

-- เครื่องที่ผู้เล่นกำลังประกอบ ช่องที่ยังไม่ได้เลือกเป็น nil
export type Build = {
	CPU: CPU?,
	Mainboard: Mainboard?,
	RAM: RAM?,
	GPU: GPU?,
	Storage: Storage?,
	PSU: PSU?,
	Case: Case?,
}

return {}
