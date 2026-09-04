# PC Shop Simulator

โปรเจคจบ: เกมจำลองร้านคอมพิวเตอร์บน Roblox (Luau) ที่สอนความรู้
เรื่องการเลือกและประกอบชิ้นส่วนคอมพิวเตอร์

## Stack
- Roblox Studio + Rojo (sync จาก src/)
- ภาษา Luau (ไม่ใช่ Lua ธรรมดา — ใช้ type annotation ได้)

## โครงสร้าง
- src/server → ServerScriptService
- src/client → StarterPlayerScripts
- src/shared → ReplicatedStorage (Data, Config, Types)

## กฎการเขียนโค้ด
- ใช้ Luau type annotation ทุกฟังก์ชัน
- ไฟล์ ModuleScript ตั้งชื่อ PascalCase
- คอมเมนต์อธิบายเป็นภาษาไทยได้ แต่ชื่อตัวแปรเป็นอังกฤษ
- ห้ามใช้ deprecated API (wait, spawn) → ใช้ task.wait, task.spawn

## ระบบหลัก
1. Customer System — สุ่มลูกค้า + โจทย์ 3 ระดับ (Clear/Unclear/Hardest)
2. PC Building — เลือกและประกอบชิ้นส่วน 7 หมวด
3. Compatibility — ตรวจ socket, ramType, watt, formFactor
4. Scoring — FitScore 50% + BudgetScore 30% + BalanceScore 20%

## กฎสำคัญ
- targetSpec (เฉลย) ห้ามส่งไปฝั่ง client เด็ดขาด ส่งได้เฉพาะ CustomerRequestPublic
- ระบบสุ่มทุกตัวต้องใช้ Random.new(seed) ห้ามใช้ math.random
- งบประมาณคิดจากราคาจริงในแคตตาล็อกแล้ว: CatalogInspector.findReferenceBuild หาชุดที่ถูกที่สุด
  ที่ตอบ targetSpec ได้และเข้ากันได้จริงครบ 7 หมวด แล้วคูณช่วงตาม RequestConfig.BudgetRange
  (สูตรประมาณเดิมใน BudgetEstimate เหลือไว้เป็นทางสำรองเท่านั้น)
- TODO: difficulty จะขึ้นกับจำนวนวันที่ผ่านไป (Day 60+ เจอ Hard บ่อยขึ้น) ยังไม่ทำในเทอมนี้