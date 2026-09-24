# PC Shop Simulator

โปรเจคจบ: เกมจำลองร้านคอมพิวเตอร์บน Roblox (Luau) ที่สอนความรู้
เรื่องการเลือกและประกอบชิ้นส่วนคอมพิวเตอร์

## Stack
- Roblox Studio + Rojo (sync จาก src/)
- ภาษา Luau (ไม่ใช่ Lua ธรรมดา — ใช้ type annotation ได้)

## โครงสร้าง
- src/server → ServerScriptService
- src/client → StarterPlayerScripts
- src/shared → ReplicatedStorage (Data, Config, Types, NPCTypes)

## กฎการเขียนโค้ด
- ใช้ Luau type annotation ทุกฟังก์ชัน
- ไฟล์ ModuleScript ตั้งชื่อ PascalCase
- คอมเมนต์อธิบายเป็นภาษาไทยได้ แต่ชื่อตัวแปรเป็นอังกฤษ
- ห้ามใช้ deprecated API (wait, spawn) → ใช้ task.wait, task.spawn

## ระบบหลัก
1. Customer System — สุ่มลูกค้า + โจทย์ 3 ระดับ (Easy/Normal/Hard)
2. PC Building — เลือกและประกอบชิ้นส่วน 7 หมวด
3. Compatibility — ตรวจ socket, ramType, watt, formFactor
4. Scoring — FitScore 50% + BudgetScore 30% + BalanceScore 20%
5. NPC System — ลูกค้าเดินตามเส้นทางคงที่ + dialogue ทีละท่อน (เกม singleplayer server จำกัด 1 คน)

## กฎสำคัญ
- targetSpec (เฉลย) ห้ามส่งไปฝั่ง client เด็ดขาด ส่งได้เฉพาะ CustomerRequestPublic
  และ DialoguePayload (NPCTypes) ซึ่งมีแค่ท่อนข้อความจาก RequestDialogue
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
    Main.Dialogue          Frame      DialogueController คุม (ซ่อนจนลูกค้ามาถึงเคาน์เตอร์)
      Dialogue.Info        TextLabel  ข้อความทีละท่อน
      Dialogue.NpcType     TextLabel  เช่น "CUSTOMER"
      Dialogue.ContinueButton  ImageButton  ไปท่อนถัดไป / ท่อนสุดท้าย = จบบทสนทนา
      Dialogue.Nametag.Name, Dialogue.NPCPfp, Dialogue.clickToCon  ยังไม่ใช้
  GUI.Upgrade              Frame      ใช้ .Visible
    Upgrade.Body.Header.Close
PlayerGui.Loading          ScreenGui  (ยังไม่มีใน Studio) LoadingScreen สร้าง placeholder ด้วยโค้ดแทน
                                      ถ้าวางของจริงใน StarterGui จะใช้ตัวนั้นอัตโนมัติ
    TextLabel "Message"               ข้อความบนจอโหลด (หาแบบ recursive)

Workspace.CamPart                        จุดกล้องโหมด Store
Workspace.CamPart2                       จุดกล้องโหมด Workshop
Workspace.Store.Furnitures.Computer      คลิกเพื่อเปิดหน้า Upgrade (อยู่ฝั่งซ้ายของร้าน)
  Computer.Highlight
Workspace.NPCs.MainNPCs                  ที่อยู่ของ NPC ที่ clone มา
Workspace.NPCs.MainNPCsPath              Part: Checkpoint1 / Checkpoint2_1 / Checkpoint2_2
                                         จุดหมุนของ NPC = CFrame ของ part พอดี (ตำแหน่ง + ทิศ)

ReplicatedStorage.Model.NPCs             model ลูกค้า (R6: Male 1, Male 2, Male 3) สุ่มหยิบมา clone
ReplicatedStorage.Remotes                RemoteEvent สร้างเองใน Studio
  GameStarted                            client → server ตอนกด Play (เริ่มส่งลูกค้า)
  DialogueShow                           server → client ส่ง DialoguePayload
  DialogueFinished                       client → server ส่ง npcId ตอนกด Continue ท่อนสุดท้าย

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
- สถานะของทุกหน้าจออยู่ในตาราง SCREENS ของ UIController
  (UI ที่แสดง, เบลอฉากหลัง, โหมดกล้อง, เอียงกล้อง, คลิก 3D, ข้อความจอโหลด)
- การเปลี่ยนฉากหรือจุดกล้องทุกครั้งต้องผ่าน LoadingScreen.transition()
  ห้าม tween CFrame ของกล้องข้ามจุด เพราะจะทะลุกำแพง
  (goTo() เรียก transition ให้เองเมื่อโหมดกล้องของหน้าใหม่ต่างจากหน้าเดิม)

ไฟล์ฝั่ง client (init.client.luau ทำให้ src/client เป็น LocalScript ชื่อ Client ไฟล์อื่นเป็น ModuleScript ลูกของมัน)
  init.client.luau                     เริ่มระบบตามลำดับ Camera → Interaction → UI (ห่อ pcall แยกกัน)
  Util/SafeFind.luau                   หา instance ตาม path + timeout + warn
  UI/UIController.luau                 ตาราง SCREENS, goTo(), ผูกปุ่ม
  UI/LoadingScreen.luau                show / hide / transition จอโหลดบังตอนเปลี่ยนฉาก (placeholder สร้างด้วยโค้ด)
  UI/UIAnimator.luau                   slideIn / slideOut / scaleTo / blurIn / blurOut / highlightIn / highlightOut
                                       / fadeIn / fadeOut (ไฟล์เดียวที่ใช้ TweenService)
                                       blur = BlurEffect "UIBlur" ใน Lighting, Enabled ค้าง true คุมด้วย Size
                                       highlight = Enabled ค้าง true คุมด้วย Fill/OutlineTransparency
  UI/ButtonEffect.luau                 ขยายตอนชี้/หดตอนกด ใส่ให้ทุก GuiButton อัตโนมัติ
  Camera/CameraController.luau         โหมด Store (CamPart) / Workshop (CamPart2) + เอียงตามเคอร์เซอร์
                                       setMode ย้ายทันที + รีเซ็ตการเอียง (ไม่มีการเลื่อนกล้องข้ามจุด)
  Interaction/InteractionService.luau  raycast ชี้/คลิกวัตถุ 3D
  UI/DialogueController.luau           รับ DialoguePayload แสดงทีละท่อน กล่องขึ้น/ปุ่ม Setting+Workshop หลบลง

## NPC System
ลำดับ (ค่าเวลาใน shared/Config/NPCConfig.luau ไม่มีการสุ่ม):
  กด Play → รอ SPAWN_INTERVAL → spawn ที่ Checkpoint1 (Queued) → หัน → เดิน Checkpoint2_1 → แวะ
  → หัน → เดิน Checkpoint2_2 → หันตามหน้า part → รอ DIALOGUE_DELAY → DialogueShow
  → ผู้เล่นกด Continue ทีละท่อนจนจบ → DialogueFinished → รอ LEAVE_DELAY → เดินกลับ Checkpoint1
  → Destroy → Idle → วนใหม่
- เดินด้วย PivotTo เส้นตรงความเร็วคงที่ (anchor root part) ทะลุกำแพงได้ ไม่ใช้ Humanoid:MoveTo
- ยังไม่มีท่าเดิน (R6) จะทำทีหลัง Humanoid เก็บไว้ใช้เล่น animation
- dialogue แยกท่อน: Greetings → Intents → Details → (IntegratedGpuNote) → BudgetPhrases
  ใช้ RequestDialogue.buildSections ส่วน build() คือท่อนเดียวกันต่อกัน

ไฟล์ฝั่ง server (init.server.luau ทำให้ src/server เป็น Script ชื่อ Server ไฟล์อื่นเป็น ModuleScript)
  init.server.luau                     เริ่มระบบ (ห่อ pcall แยกกัน)
  Systems/NPCService.luau              StoreState, spawn/เดิน/ลบ NPC, สุ่มโจทย์, ส่ง/รับ dialogue remote
  Systems/RequestGenerator.luau        สุ่มโจทย์ลูกค้า (CustomerRequest มี targetSpec)
  Systems/RequestDialogue.luau         ประโยคลูกค้า build / buildSections

## ไฟล์ dev ที่ต้องลบก่อนส่ง
- src/server/Systems/DevTest.luau (พิมพ์ targetSpec ลง Output)
