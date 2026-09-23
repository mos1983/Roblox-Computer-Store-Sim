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

## โครงสร้าง UI (ยืนยันแล้ว)
PlayerGui.Title            ScreenGui  ใช้ .Enabled
  Title.Buttons.Play       TextButton (มี LocalScript "OnClick" ข้างใน ต้องลบ)
PlayerGui.GUI              ScreenGui  ใช้ .Enabled (เปิดค้างไว้ตลอด)
  GUI.Main                 Frame      ใช้ .Visible
    Main.Balance
    Main.Day
    Main.QuestBox
    Main.SettingButton
    Main.WorkshopButton
    Main.Dialogue
  GUI.Upgrade              Frame      ใช้ .Visible
    Upgrade.Body.Header.Close

Workspace.CamPart                        จุดกล้องโหมด Store
Workspace.CamPart2                       จุดกล้องโหมด Workshop
Workspace.Store.Furnitures.Computer      คลิกเพื่อเปิดหน้า Upgrade (อยู่ฝั่งซ้ายของร้าน)
  Computer.Highlight

## ข้อจำกัดของ Claude Code ในโปรเจคนี้
- GUI และ Workspace อยู่บน Roblox cloud อ่านจากดิสก์ไม่ได้
- ใช้ path ข้างบนเท่านั้น ถ้าหา instance ไม่เจอให้ warn ชื่อ path ชัดๆ แล้วข้ามไป
  ห้ามปล่อยให้ error ลามทำให้ระบบอื่นพัง

## UI Architecture
- ห้ามฝัง LocalScript ในปุ่ม ทุกอย่างคุมผ่าน UIController
- เปลี่ยนหน้าจอผ่าน UIController.goTo() เท่านั้น
- tween ทุกตัวเรียกผ่าน UIAnimator ห้ามใช้ TweenService ตรงๆ ในไฟล์อื่น
- วัตถุ 3D ที่คลิกได้ใช้ InteractionService (raycast) ไม่ใช้ ClickDetector
  เพราะผู้เล่นไม่มีตัวละคร ClickDetector วัดระยะจาก Character จึงใช้ไม่ได้
- หา instance บน GUI/Workspace ผ่าน SafeFind.path() เสมอ (warn path เต็มแล้วคืน nil)
- สถานะของทุกหน้าจออยู่ในตาราง SCREENS ของ UIController (UI ที่แสดง, โหมดกล้อง, เอียงกล้อง, คลิก 3D)

ไฟล์ฝั่ง client (init.client.luau ทำให้ src/client เป็น LocalScript ชื่อ Client ไฟล์อื่นเป็น ModuleScript ลูกของมัน)
  init.client.luau                     เริ่มระบบตามลำดับ Camera → Interaction → UI (ห่อ pcall แยกกัน)
  Util/SafeFind.luau                   หา instance ตาม path + timeout + warn
  UI/UIController.luau                 ตาราง SCREENS, goTo(), ผูกปุ่ม
  UI/UIAnimator.luau                   slideIn / slideOut / scaleTo (ไฟล์เดียวที่ใช้ TweenService)
  UI/ButtonEffect.luau                 ขยายตอนชี้/หดตอนกด ใส่ให้ทุก GuiButton อัตโนมัติ
  Camera/CameraController.luau         โหมด Store (CamPart) / Workshop (CamPart2) + เอียงตามเคอร์เซอร์
  Interaction/InteractionService.luau  raycast ชี้/คลิกวัตถุ 3D

## ไฟล์ dev ที่ต้องลบก่อนส่ง
- src/server/Systems/DevTest.luau (พิมพ์ targetSpec ลง Output)
