# Task 4 — Checkpoint: integration + CLEANUP + ยืนยันครั้งสุดท้าย

Studio: **Edit mode ยืนยันด้วยตัวเอง** ทุก query — `RunService:IsEdit() = true`, `IsRunning() = false`
place `FarmingRobloxSimulator` (105263904115612), one window, clientId `d52e1cb2-dcea-4def-bb4d-87617e3d97d2`
(เซสชันเดียวกับ task 3.4 / 3.5 = เซสชันที่เปิด place ใหม่หลัง Ctrl+S ตอนปิด task 3.2)

ลำดับที่เดินจริง **ตามที่ task บังคับ ไม่สลับ**:
ยืนยัน 3.4/3.5 → play-test → **แล้วจึง** `CLEANUP` → query + checksum → Ctrl+S → query รอบสุดท้าย

ไม่มีการแก้ instance data ของ pet asset, `PetClient.client.lua`, `tools/CalibratePetOrientation.lua`,
`PetService`, `DataService`, `EconomyBalance` ในงานนี้ — การเปลี่ยนอย่างเดียวใน place คือ
**ลบ `Workspace.PetOrientationCalibration`** ซึ่งเป็น scaffold ชั่วคราวของ tool

---

## 1) Gate ก่อนทำอะไร — Property 1 และ Property 2 ผ่านครบ

| Property | บันทึกอยู่ที่ | ผล |
|---|---|---|
| **Property 1** (2.1–2.5) | `verification-task3.4.md` | **PASS** — 6/6 counterexample พลิกจาก FAIL → PASS, White Cat ไม่ regress, ทิศคงที่ครบ 8 สถานะ, persistence ยืนยันในเซสชันใหม่, warn ยังดังเมื่อข้อมูลไม่ครบ (4/4) |
| **Property 2** (3.1–3.7) | `verification-task3.5.md` | **PASS** — 22/22 field-by-field + 22/22 checksum + 8/8 `Evolved` + §B ตัวเลขการวางตัวตรงทุกทศนิยม + multi-owner + boost/rarity + legacy fallback 5/5 + build สะอาด |

**ข้อค้างเดียวที่ยกมาปิดใน task นี้:** `verification-task3.5.md` §G ข้อ **G5** — ค่า `Pet Boost: +N%` บน HUD
ยืนยันไว้แค่เชิงคุณภาพ (ผู้ใช้ตอบ "ดีหมด" โดยไม่ได้ให้ตัวเลข) → ปิดในข้อ 2 ข้างล่าง

## 2) Integration play-test (ผู้ใช้เล่นจริง — Ctrl+S → Play)

ถามเป็นรอบเดียวรวม 4 หัวข้อ **ก่อน** `CLEANUP` ผู้ใช้ตอบว่า **ผ่านหมดทั้ง 4 ข้อ**

| # | หัวข้อ | เกณฑ์ | ผล |
|---|---|---|---|
| 1 | **Full loop** | ซื้อ Common Egg → roll → equip → เดินรอบฟาร์ม → เพ็ตหันหน้าออก และ boost ทำงานเหมือนเดิม | **PASS** |
| 2 | **HUD readout (ปิด G5)** | อ่านข้อความบน HUD ตรง ๆ | **PASS** — ผู้ใช้รายงาน **`White Cat → Pet Boost: +6%`** |
| 3 | **สลับ equip ครบ 7 ตัวในเซสชันเดียว** | ไม่มีตัวไหนกลับด้าน · ไม่มี follower ค้างจากตัวก่อน · ไม่จมพื้น ไม่ลอย ไม่เอียง | **PASS** |
| 4 | **เงา / collision** | เพ็ตไม่ทอดเงา และเดินทะลุผ่านได้ (ไม่ชน) | **PASS** |

### G5 ปิดสนิทแล้ว — ตัวเลขตรงกับตารางในซอร์ส

`White Cat → +6%` ตรงกับ `EconomyBalance.PET_BOOSTS["Common Egg"]["White Cat"] = 6` เป๊ะ
และตรงกับค่าที่ `baseline-task2.md` §G5 **คาดไว้ล่วงหน้าว่าควรได้ `+6%`** → ไม่ใช่การยืนยันแบบ post-hoc

ยืนยันเส้นทางของเลขนี้จากซอร์สที่พิสูจน์แล้วว่าไม่ถูกแตะ (`EconomyBalance.lua` ไม่อยู่ใน git modified):
`PET_BOOSTS = 6` → server ตั้ง attribute `PetBoost = 1.06` →
`src/client/hud/PetBoost.client.lua`: `math.floor((1.06 − 1) × 100) = 6` → `Pet Boost: +6%` ✔

ตารางอ้างอิงของ Common Egg (ค่าที่ควรได้ต่อตัว): Dog 5 · Happy Dog 5 · Dark Dog 6 · **White Cat 6** ·
Black Cat 7 · White Rabbit 7 · Pink Rabbit 8 — ผู้ใช้อ่านมา 1 ตัวจาก 7 และ **ตรง** ส่วนอีก 6 ตัวยืนยันเชิง
พฤติกรรมว่า "boost ทำงานเหมือนเดิม" (ข้อ 1) โดยยังไม่มี readout ตัวเลขรายตัว — บันทึกตามจริง ไม่ขยายความ
ความเสี่ยงที่เหลือต่ำมาก เพราะทั้ง 6 ตัวใช้โค้ดเส้นเดียวกันกับ White Cat และ `PET_BOOSTS` 22/22 ยืนยันแล้วว่า
lookup ครบ 1:1 (`verification-task3.5.md` §D)

## 3) `ACTION = "CLEANUP"` — รันหลัง play-test ผ่านแล้วเท่านั้น

รันใน **Command Bar, Edit mode** โดย**ไม่เซฟ**ค่า `ACTION` ลงไฟล์ tool (แก้ในเอดิเตอร์ → paste → Ctrl+Z)

อ่านโค้ด `cleanup()` ก่อนสั่งรัน เพื่อยืนยันว่า blast radius แคบจริง:

```lua
local function cleanup()
	local folder = Workspace:FindFirstChild(CALIBRATION_NAME)
	if folder then folder:Destroy() end
	print("[PetCalibration] Calibration area removed. Pet assets were not changed.")
end
```
→ แตะเฉพาะ `Workspace.PetOrientationCalibration` ไม่มีเส้นทางใดเข้าถึง `ReplicatedStorage.Assets.Pets`
และไม่ใช้ `SCOPE` / `CONFIRM_BAKE` เลย

**สภาพก่อนรัน** (query จริง): `Workspace.PetOrientationCalibration` มี **6 station** —
`Common Egg__Dog`, `__Dark Dog`, `__Happy Dog`, `__White Rabbit`, `__Black Cat`, `__Pink Rabbit`

**output ที่ผู้ใช้ได้ (คำต่อคำ):**
```
20:58:36.596  [PetCalibration] Calibration area removed. Pet assets were not changed.  -  Edit
```
บรรทัดเดียว ไม่มี `error` ไม่มี `warn`

## 4) ยืนยันหลัง CLEANUP — folder หาย, pet asset ไม่ถูกแตะ

สคริปต์ checksum: **`verification-task3.2.md` §6 ตรงตัว** (rel CFrame ต่อ BasePart ที่ไม่ใช่ root → sort →
FNV-1a 32-bit) ไม่ได้เปลี่ยน format

```
CALIB_FOLDER = GONE
STRAYS = none          -- สแกน Workspace ทั้งต้นหา "PetOrientationCalibration" และ "Common Egg__*"
```

### checksum ทั้ง 22 ตัว เทียบ §6 / task 3.4 / task 3.5

| Egg | Pet | parts / geom | checksum หลัง CLEANUP | §6 | ผล |
|---|---|---|---|---|---|
| Common Egg | **White Cat** | 4 / 3 | **`7F3783E0`** | `7F3783E0` | **MATCH (= ค่าก่อนแก้) 3.1** |
| Common Egg | Black Cat | 2 / 1 | `2A5B6215` | `2A5B6215` | MATCH |
| Common Egg | Dark Dog | 2 / 1 | `B0C27678` | `B0C27678` | MATCH |
| Common Egg | Dog | 2 / 1 | `C83DA768` | `C83DA768` | MATCH |
| Common Egg | Happy Dog | 2 / 1 | `07DE2E38` | `07DE2E38` | MATCH |
| Common Egg | Pink Rabbit | 2 / 1 | `DFC796B0` | `DFC796B0` | MATCH |
| Common Egg | White Rabbit | 2 / 1 | `1F5B87C0` | `1F5B87C0` | MATCH |
| Uncommon Egg | MewWat | 14 / 13 | `D11D1190` | `D11D1190` | MATCH |
| Uncommon Egg | Snow Cat | 14 / 13 | `F166FE08` | `F166FE08` | MATCH |
| Godly Egg | BoBo | 20 / 19 | `89D644F0` | `89D644F0` | MATCH |
| Godly Egg | Bluehoo | 43 / 42 | `376999EB` | `376999EB` | MATCH |
| Godly Egg | Thorney | 26 / 25 | `03479EE0` | `03479EE0` | MATCH |
| Godly Egg | Fireclouds | 36 / 35 | `8ACDC790` | `8ACDC790` | MATCH |
| Galactic Egg | Bluewing | 16 / 15 | `F1FD0150` | `F1FD0150` | MATCH |
| Galactic Egg | PinkPig | 11 / 10 | `04A63018` | `04A63018` | MATCH |
| Galactic Egg | Whitebear | 16 / 15 | `1030D370` | `1030D370` | MATCH |
| Galactic Egg | Blackbear | 16 / 15 | `040EA878` | `040EA878` | MATCH |
| Galactic Egg | GoldPig | 11 / 10 | `A596576E` | `A596576E` | MATCH |
| Galactic Egg | Brownbear | 16 / 15 | `320F0E80` | `320F0E80` | MATCH |
| Divine Egg | Sun Flare | 13 / 12 | `D6A916E8` | `D6A916E8` | MATCH |
| Divine Egg | Moon Flare | 13 / 12 | `916888D8` | `916888D8` | MATCH |
| Divine Egg | Moon | 5 / 4 | `1F27A14C` | `1F27A14C` | MATCH |

**22/22 MATCH** · part count ตรงกับ `baseline-task2.md` §A.1 ทุกแถว
`FacingAttachment.CFrame` ของทั้ง 22 ตัวยังเท่ากันทุก component และเท่ากับ baseline §A.0:
`[0,0,0, −1,0,−0, 0,1,0, 0,0,−1]` · attributes บน Model = **0 ตัวทุกตัว** (ไม่มี `FacingOffset*` ค้าง)

### `Evolved` legacy Model 8 ตัว

| Egg | Model | `FollowerRoot` | `PrimaryPart` | `FacingAttachment` | attributes |
|---|---|---|---|---|---|
| Godly Egg | Evolved Aether / Primus / Hyperion | none | `Head` | none | 0 |
| Galactic Egg | Evolved Galactic Lord / Galactic Overlord | none | `Head` | none | 0 |
| Divine Egg | Evolved Divine Sun / The Star of Lakshmi / Polygonis | none | `Head` | none | 0 |

**8/8 เท่ากับ baseline §A.2** — ไม่ถูก calibrate ไม่ถูกลบ ไม่ถูกเพิ่ม field

## 5) Ctrl+S → query รอบสุดท้าย

ผู้ใช้ Ctrl+S หลัง CLEANUP แล้วยืนยัน จากนั้น query อีกครั้ง (assertion แบบ pass/fail ไม่ใช่แค่ dump ค่า):

```
FINAL isEdit=true isRunning=false
CALIB_FOLDER              = GONE
GEN2_ROWS                 = 22/22
CHECKSUM_MISMATCH         = NONE (22/22 MATCH)
GEN2_CONTRACT_VIOLATIONS  = NONE
MISSING_MODELS            = none
EVOLVED                   = 8/8  violations=NONE
```

`GEN2_CONTRACT_VIOLATIONS` ตรวจต่อตัวครบทุกเงื่อนไขของสัญญา calibration:
`PrimaryPart == FollowerRoot` · `FacingAttachment` เป็น `Attachment` · `Transparency == 1` ·
`Anchored == true` · `CanCollide == false` · `Size == (1,1,1)` · attributes = 0 → **ไม่มีตัวใดหลุด**

`MISSING_MODELS = none` = ไม่มี pet Model ตัวใดหายไประหว่าง CLEANUP (เทียบกับรายชื่อ 22 ตัวใน §6)

## 6) สภาพ repo หลังปิดงาน

`tools/CalibratePetOrientation.lua` บนดิสก์กลับเป็นค่าปลอดภัยแล้ว — **กันเผลอ bake/cleanup ซ้ำ**:
```lua
local ACTION = "SETUP"
local SCOPE = "SELECTED"
local CONFIRM_BAKE = false
```

`git status --porcelain` **เท่ากับ `verification-task3.5.md` §F เป๊ะทุกบรรทัด**:
```
 M .kiro/settings/mcp.json
 M default.project.json
 M src/client/world/WeatherClient.client.lua
 M src/shared/Modules/WeatherSounds.lua
 M tools/IntegrateCropFromSelection.lua
 M tools/IntegratePetsFromSelection.lua
 M tools/MigrateNewFarmSoil.lua
?? .kiro/specs/pet-facing-direction-fix/
?? .kiro/specs/rain-visual-polish/
?? .kiro/specs/thunderstorm-polish/
?? src/shared/Modules/RainVisualConfig.lua
```
→ ไม่มีไฟล์ใดถูกแตะเพิ่มใน task 4 · commit ของงานนี้ยังเป็น `4fad98c` (task 3.1 — tool)
และ `c51bd5e` (task 3.3 — `PetClient.client.lua`) · ไม่ต้อง build ใหม่เพราะไม่มี source เปลี่ยน
(`rojo build` EXIT=0 บันทึกไว้แล้วใน `verification-task3.5.md` §F)

---

## สรุปผล task 4 — ผ่านครบทุกข้อ งานปิดได้

| ข้อใน task 4 | เกณฑ์ | ผล |
|---|---|---|
| Integration full loop | ซื้อ → roll → equip → เดินรอบฟาร์ม, หน้าออก + boost ทำงาน | **PASS** (play-test) |
| สลับ 7 ตัวในเซสชันเดียว | ไม่กลับด้าน · ไม่มี follower ค้าง · ไม่จม/ลอย/เอียง · เงา+collision ปิด | **PASS** (play-test) |
| `CLEANUP` หลัง play-test | รันหลังยืนยันจริงเท่านั้น → folder หาย → Ctrl+S → query ปิดท้าย | **PASS** |
| pet asset ไม่ถูกแตะจาก CLEANUP | checksum 22/22 + สัญญา gen2 0 violation + `Evolved` 8/8 | **PASS** |
| Property 1 (task 3.4) | ยืนยันว่าผ่านครบ | **PASS** |
| Property 2 (task 3.5) | ยืนยันว่าผ่านครบ | **PASS** |
| G5 ที่ค้างจาก task 3.5 | readout ตัวเลข HUD จริง | **ปิดแล้ว** — `White Cat → Pet Boost: +6%` ตรงกับ `PET_BOOSTS = 6` |

**ไม่มีข้อใดค้างที่ต้องถามผู้ใช้ต่อ** ทุกข้อที่ task 4 ระบุมีหลักฐานรองรับ

### สิ่งที่พูดตรง ๆ ว่าไม่ได้ทำ (ไม่ทำให้ดูแข็งกว่าที่เป็น)

- **readout HUD อ่านมา 1 ตัวจาก 7** (`White Cat +6%`) อีก 6 ตัวยืนยันเชิงพฤติกรรมว่า boost ทำงานเหมือนเดิม
  ไม่ได้อ่านเลขรายตัว — โค้ดเส้นเดียวกันและ `PET_BOOSTS` 22/22 1:1 จึงถือว่าความเสี่ยงต่ำ แต่**ไม่ใช่**
  การวัดครบ 7 ตัว
- **ไม่ได้ปิด/เปิด place ใหม่อีกรอบหลัง CLEANUP** — persistence รอบนี้ยืนยันด้วย Ctrl+S + query หลังเซฟ
  ในเซสชันเดิม (การปิด/เปิด place ทำแล้วในรอบที่สำคัญกว่าคือหลัง BAKE ที่ task 3.2 §5 ซึ่งเป็นตอนที่
  geometry เปลี่ยนจริง) CLEANUP เป็นการ **ลบ** scaffold ไม่ใช่การเขียนค่าลง asset
- **ไม่ได้ re-run multi-client 2 players ใน task 4** — บันทึกไว้แล้วที่ `verification-task3.5.md` §C/§G4
  และ `PetService` ไม่ถูกแตะระหว่าง task นี้

**ขั้นถัดไปที่แนะนำ (นอกขอบเขต task นี้ ต้องให้ผู้ใช้สั่ง):** commit โฟลเดอร์ spec
`.kiro/specs/pet-facing-direction-fix/` ที่ยัง untracked เพื่อเก็บบันทึกทั้งชุดไว้กับ repo
(ภาคผนวก Runbook ใน `verification-task3.5.md` ใช้ซ้ำได้เวลาเพ็ตเทียร์อื่นหันผิด)
