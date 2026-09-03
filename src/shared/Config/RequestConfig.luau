--!strict
-- RequestConfig.luau — ค่าตั้งของระบบสุ่มโจทย์ลูกค้า
-- แยกออกมาเป็นไฟล์เดียวเพื่อให้ปรับสมดุลเกมได้โดยไม่ต้องแตะ logic
-- ทุกตาราง freeze ไว้กันเผลอแก้ค่าตอน runtime

local Types = require(script.Parent.Parent.Types)

type SpecProfile = Types.SpecProfile
type UseCase = Types.UseCase
type Difficulty = Types.Difficulty

-- ช่วงตัวคูณงบประมาณ (คูณกับราคาประมาณของสเปกเป้าหมาย)
export type BudgetMultiplier = {
	min: number,
	max: number,
}

-- ช่วงสุ่ม alpha แบบ { ต่ำสุด, สูงสุด } — 0 = เท่ากับ minSpec, 1 = เท่ากับ recommendedSpec
export type AlphaRange = { number }

export type BudgetEstimateConfig = {
	BASE_COST: number,
	PRICE_PER_POINT: SpecProfile,
}

--[[
	น้ำหนักความสำคัญของแต่ละหมวดตามการใช้งาน ใช้เป็น weights ตอนคิด FitScore
	แต่ละชุดรวมกันได้ 1.0 พอดี ถ้าแก้ค่าต้องคุมผลรวมไว้เท่าเดิม
]]
local UseCaseWeights: { [UseCase]: SpecProfile } = table.freeze({
	gaming = table.freeze({ CPU = 0.25, GPU = 0.50, RAM = 0.15, Storage = 0.10 }),
	editing = table.freeze({ CPU = 0.35, GPU = 0.25, RAM = 0.30, Storage = 0.10 }),
	office = table.freeze({ CPU = 0.30, GPU = 0.10, RAM = 0.25, Storage = 0.35 }),
	streaming = table.freeze({ CPU = 0.40, GPU = 0.35, RAM = 0.20, Storage = 0.05 }),
})

--[[
	สูตรประมาณราคาของสเปกเป้าหมาย: BASE_COST + ผลรวม(perfScore × PRICE_PER_POINT ของหมวดนั้น)
	BASE_COST คิดรวมเมนบอร์ด + PSU + เคส ซึ่งยังไม่ผูกกับสเปกที่ลูกค้าขอ
	TODO: เปลี่ยนไปคิดจากราคาจริงในแคตตาล็อกเมื่อมีข้อมูลครบทั้ง 7 หมวด
]]
local BudgetEstimate: BudgetEstimateConfig = table.freeze({
	BASE_COST = 6000,
	PRICE_PER_POINT = table.freeze({ CPU = 220, GPU = 260, RAM = 90, Storage = 60 }),
})

-- ตัวคูณช่วงงบตามระดับความยาก ยิ่งยากช่วงยิ่งแคบ (เผื่อให้เลือกผิดได้น้อยลง)
local BudgetRange: { [Difficulty]: BudgetMultiplier } = table.freeze({
	Easy = table.freeze({ min = 0.95, max = 1.30 }),
	Normal = table.freeze({ min = 0.95, max = 1.20 }),
	Hard = table.freeze({ min = 0.95, max = 1.10 }),
})

-- ช่วงสุ่มตำแหน่งของ targetSpec ระหว่าง minSpec กับ recommendedSpec
local SpecAlphaRange: { [Difficulty]: AlphaRange } = table.freeze({
	Easy = table.freeze({ 0.0, 0.5 }),
	Normal = table.freeze({ 0.3, 0.8 }),
	Hard = table.freeze({ 0.5, 1.0 }),
})

local RequestConfig = {
	UseCaseWeights = UseCaseWeights,
	BudgetEstimate = BudgetEstimate,
	BudgetRange = BudgetRange,
	SpecAlphaRange = SpecAlphaRange,
}

return table.freeze(RequestConfig)
