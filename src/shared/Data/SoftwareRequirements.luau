--!strict
-- SoftwareRequirements.luau — ความต้องการสเปกของซอฟต์แวร์/เกม ใช้เป็นวัตถุดิบของโจทย์ลูกค้า
-- ตัวเลขทุกช่องเป็นหน่วยเดียวกับ perfScore ของชิ้นส่วน (0-100) เทียบกันได้ตรง ๆ
-- GPU = 0 คือการ์ดจอออนบอร์ดเอาอยู่ ไม่ต้องซื้อการ์ดจอแยก
-- ค่าพวกนี้ปรับสมดุลด้วยมือเพื่อให้เกมสนุก ไม่ได้ผูกกับ benchmark จริง

local Types = require(script.Parent.Parent.Types)

local SoftwareRequirements: { Types.SoftwareRequirement } = {
	-- ===== office — งานเอกสาร/ประชุม =====
	{
		id = "sw_macrohard",
		name = "Macrohard 365 (Letter / Table / PointPower)",
		useCase = "office",
		minSpec = { CPU = 8, GPU = 0, RAM = 10, Storage = 10 },
		recommendedSpec = { CPU = 25, GPU = 0, RAM = 25, Storage = 35 },
	},
	{
		id = "sw_boom_hd",
		name = "Boom / Doodle Meet ประชุม HD",
		useCase = "office",
		minSpec = { CPU = 12, GPU = 0, RAM = 15, Storage = 10 },
		recommendedSpec = { CPU = 30, GPU = 10, RAM = 30, Storage = 30 },
	},
	{
		id = "sw_manualcad",
		name = "ManualCAD 2025",
		useCase = "office",
		minSpec = { CPU = 30, GPU = 25, RAM = 35, Storage = 35 },
		recommendedSpec = { CPU = 55, GPU = 50, RAM = 55, Storage = 60 },
	},
	{
		id = "sw_titanium_browser",
		name = "Titanium Browser (เปิดทีเดียว 100 Tab)",
		useCase = "office",
		minSpec = { CPU = 15, GPU = 0, RAM = 30, Storage = 15 },
		recommendedSpec = { CPU = 35, GPU = 15, RAM = 60, Storage = 25 },
	},

	-- ===== gaming — เรียงจากเบาไปหนัก =====
	{
		id = "sw_roblox",
		name = "Roblox",
		useCase = "gaming",
		minSpec = { CPU = 8, GPU = 0, RAM = 10, Storage = 10 },
		recommendedSpec = { CPU = 25, GPU = 15, RAM = 25, Storage = 30 },
	},
	{
		id = "sw_ourcraft",
		name = "Ourcraft: Bedrock Edition",
		useCase = "gaming",
		minSpec = { CPU = 12, GPU = 0, RAM = 15, Storage = 10 },
		recommendedSpec = { CPU = 35, GPU = 25, RAM = 40, Storage = 35 },
	},
	{
		id = "sw_valorant",
		name = "VALORANT (1080p 144fps)",
		useCase = "gaming",
		minSpec = { CPU = 12, GPU = 5, RAM = 15, Storage = 15 },
		recommendedSpec = { CPU = 35, GPU = 30, RAM = 35, Storage = 40 },
	},
	{
		id = "sw_ptm5",
		name = "Petty Theft Manual V (1080p High)",
		useCase = "gaming",
		minSpec = { CPU = 20, GPU = 18, RAM = 20, Storage = 25 },
		recommendedSpec = { CPU = 45, GPU = 45, RAM = 40, Storage = 45 },
	},
	{
		id = "sw_cs2",
		name = "Counter-Strike 2 (1080p 240fps)",
		useCase = "gaming",
		minSpec = { CPU = 25, GPU = 20, RAM = 25, Storage = 30 },
		recommendedSpec = { CPU = 55, GPU = 45, RAM = 45, Storage = 55 },
	},
	{
		id = "sw_steampunk",
		name = "Steampunk 1877 (1440p Ultra)",
		useCase = "gaming",
		minSpec = { CPU = 40, GPU = 40, RAM = 40, Storage = 45 },
		recommendedSpec = { CPU = 70, GPU = 80, RAM = 60, Storage = 70 },
	},
	{
		id = "sw_bark_extinction",
		name = "BARK: Extinction Devolved (ลง Mod ไดโนเสาร์เต็มสูบ)",
		useCase = "gaming",
		minSpec = { CPU = 45, GPU = 50, RAM = 45, Storage = 60 },
		recommendedSpec = { CPU = 75, GPU = 85, RAM = 75, Storage = 85 },
	},
	{
		id = "sw_elderly_ring",
		name = "Elderly Ring (Open World ปาจอยพัง)",
		useCase = "gaming",
		minSpec = { CPU = 35, GPU = 40, RAM = 35, Storage = 45 },
		recommendedSpec = { CPU = 65, GPU = 70, RAM = 55, Storage = 60 },
	},
	{
		id = "sw_gacha_bounce",
		name = "Gacha Bounce (Open World Action RPG)",
		useCase = "gaming",
		minSpec = { CPU = 20, GPU = 20, RAM = 20, Storage = 35 },
		recommendedSpec = { CPU = 45, GPU = 40, RAM = 40, Storage = 55 },
	},
	{
		id = "sw_basemyths",
		name = "Base Myths (Battle Royale เร็วทะลุนรก)",
		useCase = "gaming",
		minSpec = { CPU = 25, GPU = 25, RAM = 25, Storage = 30 },
		recommendedSpec = { CPU = 50, GPU = 45, RAM = 45, Storage = 45 },
	},
	{
		id = "sw_peacegrounds",
		name = "UnknownPlayer's Peacegrounds",
		useCase = "gaming",
		minSpec = { CPU = 25, GPU = 30, RAM = 30, Storage = 35 },
		recommendedSpec = { CPU = 55, GPU = 55, RAM = 45, Storage = 50 },
	},

	-- ===== editing — งานภาพ/วิดีโอ/3D =====
	{
		id = "sw_adobo_photochop",
		name = "Adobo PhotoChop",
		useCase = "editing",
		minSpec = { CPU = 25, GPU = 20, RAM = 30, Storage = 30 },
		recommendedSpec = { CPU = 55, GPU = 45, RAM = 55, Storage = 60 },
	},
	{
		id = "sw_davinci_confuse",
		name = "DaVinci Confuse (ตัดต่อ 1080p)",
		useCase = "editing",
		minSpec = { CPU = 35, GPU = 35, RAM = 40, Storage = 40 },
		recommendedSpec = { CPU = 65, GPU = 60, RAM = 60, Storage = 65 },
	},
	{
		id = "sw_adobo_finale_noob",
		name = "Adobo Finale Noob (ตัดต่อ 4K)",
		useCase = "editing",
		minSpec = { CPU = 45, GPU = 40, RAM = 50, Storage = 50 },
		recommendedSpec = { CPU = 80, GPU = 70, RAM = 75, Storage = 80 },
	},
	{
		id = "sw_mixer_cycles",
		name = "Mixer 3D (เรนเดอร์ Cycles ด้วย GPU)",
		useCase = "editing",
		minSpec = { CPU = 40, GPU = 45, RAM = 45, Storage = 40 },
		recommendedSpec = { CPU = 75, GPU = 85, RAM = 70, Storage = 65 },
	},

	-- ===== streaming — ไลฟ์สด =====
	{
		id = "sw_cbs_1080p",
		name = "CBS Studio สตรีมเกม 1080p60",
		useCase = "streaming",
		minSpec = { CPU = 35, GPU = 30, RAM = 35, Storage = 35 },
		recommendedSpec = { CPU = 65, GPU = 60, RAM = 55, Storage = 60 },
	},
	{
		id = "sw_cbs_1440p_dual",
		name = "สตรีม 1440p60 พร้อมเล่นเกมหนักในเครื่องเดียว",
		useCase = "streaming",
		minSpec = { CPU = 55, GPU = 55, RAM = 50, Storage = 50 },
		recommendedSpec = { CPU = 85, GPU = 80, RAM = 70, Storage = 70 },
	},
	{
		id = "sw_flinch_vtuber",
		name = "Flinch Studio (รันโมเดล VTuber 3D Avatar)",
		useCase = "streaming",
		minSpec = { CPU = 45, GPU = 40, RAM = 45, Storage = 40 },
		recommendedSpec = { CPU = 75, GPU = 70, RAM = 65, Storage = 60 },
	},
}

-- freeze รายรายการ (table.freeze เป็นแบบตื้น ต้องลงไปถึง spec ด้วย)
for _, software in SoftwareRequirements do
	table.freeze(software.minSpec)
	table.freeze(software.recommendedSpec)
	table.freeze(software)
end

return table.freeze(SoftwareRequirements)
