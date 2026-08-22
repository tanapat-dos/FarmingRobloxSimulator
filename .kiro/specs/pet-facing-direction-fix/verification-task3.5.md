# Task 3.5 — รันชุดตรวจ preservation เดิมจาก task 2 ซ้ำ (Property 2)

ชุดตรวจ = **ชุดเดิม §A–§G จาก `baseline-task2.md`** ไม่ได้เขียนชุดใหม่ ทุกข้อ diff **ทีละ field** กับค่าที่บันทึกไว้

Studio: **Edit mode ยืนยันด้วยตัวเอง** — `RunService:IsEdit() = true`, `IsRunning() = false`
place `FarmingRobloxSimulator` (105263904115612), one window, clientId `d52e1cb2-dcea-4def-bb4d-87617e3d97d2`
(เซสชันเดียวกับ task 3.4 = เซสชันที่เปิด place ใหม่หลัง Ctrl+S ตอนปิด task 3.2)

**verification-only** — ไม่มี instance data / tool / source file ใดถูกแก้ระหว่าง task นี้
**ไม่ได้รัน `ACTION = "CLEANUP"`** — `workspace.PetOrientationCalibration` ยังอยู่ ตรวจแล้วมีลูก **6 station** (งานของ task 4)

## หมายเหตุเรื่อง checksum ของ baseline §A.1 (สืบทอดจาก task 3.2)

checksum ใน `baseline-task2.md` §A.1 **reproduce ไม่ได้** เพราะเอกสารไม่ได้เก็บสคริปต์ hashing ต้นฉบับไว้
(task 3.2 §4 ลอง 8 รูปแบบแล้วไม่คืนค่าเดิม) task นี้จึง **ไม่เสียเวลา reverse-engineer format นั้น**
แต่ใช้สคริปต์ที่ reproduce ได้จาก `verification-task3.2.md` §6 ตรงตัว แล้ว diff กับตาราง §6
(ค่าที่จับหลัง BAKE + ยืนยันหลังเปิด place ใหม่ + re-confirm อีกครั้งใน task 3.4)

สำหรับเพ็ต egg อื่น assertion ที่มีความหมายจริงคือ **สองข้อคู่กัน**:
1. checksum **ไม่เปลี่ยนจาก §6** (และจาก task 3.4)
2. **โครงสร้างเหมือน baseline §A.0 ทุก field** — `FollowerRoot` ครบ, `PrimaryPart == FollowerRoot`,
   `FacingAttachment.CFrame` เท่ากันทุก component, ไม่มี attribute `FacingOffset*`

---

## §A.0 — invariant baseline: ตรงกับ baseline ทุก field ครบ 22 ตัว

ตรวจครบทุก pet Model ในทุก egg folder (enumerate ไม่สุ่ม) — **ไม่มีตัวใดหลุดแม้แต่ field เดียว**

| Field | ค่า baseline §A.0 | ค่าที่วัดได้ตอนนี้ | ผล |
|---|---|---|---|
| `FollowerRoot` มี + `ClassName = Part` + เป็นลูกตรง | ทุกตัว | **22/22** | MATCH |
| `Model.PrimaryPart == FollowerRoot` | `true` ทุกตัว | **22/22 true** | MATCH |
| `FollowerRoot.Size` | `(1,1,1)` | **22/22 `1.0000,1.0000,1.0000`** | MATCH |
| `FollowerRoot.Transparency` | `1.000000` | **22/22 `1.0000`** (violations = none) | MATCH |
| `FollowerRoot.Anchored` | `true` | **22/22 true** (violations = none) | MATCH |
| `FollowerRoot.CanCollide` | `false` | **22/22 false** (violations = none) | MATCH |
| `FacingAttachment` มี + เป็น `Attachment` ใน root | ทุกตัว | **22/22** | MATCH |
| `FacingAttachment.CFrame` 12 components | `[0,0,0, −1,0,−0, 0,1,0, 0,0,−1]` | **22/22 `EXACT_MATCH_A0`** (ไม่มี component ใดต่างเกิน `1e-6`) | MATCH |
| `FacingAttachment.CFrame.LookVector` | `(0,−0,1)` → **+Z** | **22/22 `0.000000,-0.000000,1.000000`** | MATCH |
| attributes บน Model | `{}` ว่างเปล่า | **22/22 `{}`** — ไม่มี `FacingOffsetX/Y/Z` / `FacingOffsetDegrees` และไม่มี attribute อื่นเลย | MATCH |
| tier | gen2 ทุกตัว | **gen2 22/22** | MATCH |

`FollowerRoot` ทั้ง 22 ตัวมี **signature เดียวกันหมด 1 แบบ** (นับได้ 22/22 ในกลุ่มเดียว):
`CanCollide=false | Anchored=true | Plastic | 1.0000,1.0000,1.0000 | 163,162,165 | Reflectance=0.0000`
→ diff ที่ task 3.2 §1 ข้อ 2 แก้ไว้ (ทำ station root ให้เท่า `White Cat`) ยังคงอยู่ ไม่มีตัวใด drift กลับ

`FollowerRoot.CFrame.LookVector` = `(−0.000000, −0.000000, −1.000000)` ทุกตัว ยกเว้น
`Dog` = `(−0.000026, −0.000000, −1.000000)` และ `Black Cat` = `(−0.000026, −0.000000, −0.999999)`
— **เท่ากับที่ task 3.4 §1 บันทึกไว้เป๊ะ ไม่ใช่ค่าใหม่** (0.0015° ต่ำกว่า tolerance ±10° ของ 2.1 ราว 6,700 เท่า)

## §A.1 — checksum + part count ต่อตัว ครบ 22 แถว (3.1, 3.2)

สคริปต์: `verification-task3.2.md` §6 ตรงตัว (rel CFrame ต่อ BasePart ที่ไม่ใช่ root → sort → FNV-1a 32-bit)

| Egg | Pet | baseParts (baseline §A.1) | วัดได้ | geom parts | checksum ตอนนี้ | §6 / task 3.4 | ผล |
|---|---|---|---|---|---|---|---|
| Common Egg | Black Cat | 2 | **2** | 1 | `2A5B6215` | `2A5B6215` | MATCH |
| Common Egg | Dark Dog | 2 | **2** | 1 | `B0C27678` | `B0C27678` | MATCH |
| Common Egg | Dog | 2 | **2** | 1 | `C83DA768` | `C83DA768` | MATCH |
| Common Egg | Happy Dog | 2 | **2** | 1 | `07DE2E38` | `07DE2E38` | MATCH |
| Common Egg | Pink Rabbit | 2 | **2** | 1 | `DFC796B0` | `DFC796B0` | MATCH |
| Common Egg | White Rabbit | 2 | **2** | 1 | `1F5B87C0` | `1F5B87C0` | MATCH |
| Common Egg | **White Cat** | 4 | **4** | 3 | **`7F3783E0`** | `7F3783E0` | **MATCH (= ค่าก่อนแก้) 3.1** |
| Uncommon Egg | MewWat | 14 | **14** | 13 | `D11D1190` | `D11D1190` | MATCH |
| Uncommon Egg | Snow Cat | 14 | **14** | 13 | `F166FE08` | `F166FE08` | MATCH |
| Godly Egg | Bluehoo | 43 | **43** | 42 | `376999EB` | `376999EB` | MATCH |
| Godly Egg | BoBo | 20 | **20** | 19 | `89D644F0` | `89D644F0` | MATCH |
| Godly Egg | Fireclouds | 36 | **36** | 35 | `8ACDC790` | `8ACDC790` | MATCH |
| Godly Egg | Thorney | 26 | **26** | 25 | `03479EE0` | `03479EE0` | MATCH |
| Galactic Egg | Blackbear | 16 | **16** | 15 | `040EA878` | `040EA878` | MATCH |
| Galactic Egg | Bluewing | 16 | **16** | 15 | `F1FD0150` | `F1FD0150` | MATCH |
| Galactic Egg | Brownbear | 16 | **16** | 15 | `320F0E80` | `320F0E80` | MATCH |
| Galactic Egg | GoldPig | 11 | **11** | 10 | `A596576E` | `A596576E` | MATCH |
| Galactic Egg | PinkPig | 11 | **11** | 10 | `04A63018` | `04A63018` | MATCH |
| Galactic Egg | Whitebear | 16 | **16** | 15 | `1030D370` | `1030D370` | MATCH |
| Divine Egg | Moon | 5 | **5** | 4 | `1F27A14C` | `1F27A14C` | MATCH |
| Divine Egg | Moon Flare | 13 | **13** | 12 | `916888D8` | `916888D8` | MATCH |
| Divine Egg | Sun Flare | 13 | **13** | 12 | `D6A916E8` | `D6A916E8` | MATCH |

- **part count: 22/22 ตรงกับ baseline §A.1** (คอลัมน์ที่ reproduce ได้จากเอกสาร baseline โดยตรง)
- **checksum: 22/22 ตรงกับ §6** → geometry ของ **15 เพ็ต egg อื่น + White Cat ไม่ถูกแตะ** และ 6 ตัวที่แก้
  ไม่มี drift เพิ่มหลัง task 3.2/3.4
- จำนวนรวม = **22 แถว** (Common 7, Uncommon 2, Godly 4, Galactic 6, Divine 3) ตรงกับตาราง §A.1
  (prose ใน baseline เขียน "23" คลาดเอง — ตัวเลขในตารางถูก ยืนยันซ้ำใน task 3.2 §6)

## §A.2 — `Evolved` legacy Model 8 ตัว ยังไม่ถูกแตะ (3.2, 3.6)

| Egg | Model | `FollowerRoot` | `PrimaryPart` | `FacingAttachment` | attributes | ผล |
|---|---|---|---|---|---|---|
| Godly Egg | Evolved Aether | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Godly Egg | Evolved Hyperion | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Godly Egg | Evolved Primus | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Galactic Egg | Evolved Galactic Lord | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Galactic Egg | Evolved Galactic Overlord | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Divine Egg | Evolved Divine Sun | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Divine Egg | Evolved Polygonis | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |
| Divine Egg | Evolved The Star of Lakshmi | **ไม่มี** | `Head` | ไม่มี | `{}` | MATCH |

8/8 ตรงกับ baseline §A.2 ทุก field — **ไม่ถูก calibrate ไม่ถูกลบ ไม่ถูกเพิ่ม attribute**
(`SCOPE = "SELECTED"` ทำงานตามที่ตั้งใจ — ไม่มีอะไรรั่วออกนอก 6 station)

## §B — การวางตัว follower (3.3)

### §B.1 ค่าคงที่ในซอร์ส

อ่านจาก `src/client/panels/PetClient.client.lua` (commit `c51bd5e`) — วัดค่าจริงตอน runtime ด้วย:

| ค่า | baseline §B.1 | ตอนนี้ | ผล |
|---|---|---|---|
| `FOLLOW_OFFSET` | `Vector3.new(2.5, 0, 0)` | **`2.5, 0, 0`** | MATCH |
| `FOLLOW_UP` | `Vector3.new(0, 1, 0)` | **`0, 1, 0`** | MATCH |
| `model:ScaleTo(...)` | `0.75` | **`0.75`** | MATCH |
| `pivot:Lerp(target, …)` | `0.15` บน `RunService.Heartbeat` | **`0.15` / Heartbeat** | MATCH |
| `computeFollowTarget` | `lookAt(pos, pos + root.LookVector, FOLLOW_UP) * facingCorrection` | **เหมือนเดิมทุกบรรทัด** | MATCH |
| clone flags | `Anchored / CanCollide=false / CanTouch=false / CanQuery=false / CastShadow=false` | **ครบทั้ง 5** | MATCH |

### §B.2 ค่าที่วัดได้จาก logic เดิม (root ที่ `(0,5,0)` มองไป world −Z, correction = live gen2 จาก asset จริง)

รันด้วยวิธีเดียวกับ baseline — คำนวณบน `CFrame` ล้วน ไม่แตะ instance ใน place

| สถานะของ root | `target.UpVector` | `target.LookVector` | `target.Position` | offset | \|offset\| | ผล |
|---|---|---|---|---|---|---|
| flat | `0.0000,1.0000,0.0000` | `-0.0000,-0.0000,1.0000` | `2.5000,5.0000,0.0000` | `2.5000,0.0000,0.0000` | `2.5000` | MATCH |
| roll +50° (Z) | `0.0000,1.0000,0.0000` | `-0.0000,-0.0000,1.0000` | `1.6070,6.9151,0.0000` | `1.6070,1.9151,0.0000` | `2.5000` | MATCH |
| roll +180° (Z, ragdoll คว่ำ) | `0.0000,1.0000,0.0000` | `-0.0000,-0.0000,1.0000` | `-2.5000,5.0000,0.0000` | `-2.5000,0.0000,0.0000` | `2.5000` | MATCH |
| pitch +35° (X) | `0.0000,0.8192,0.5736` | `-0.0000,-0.5736,0.8192` | `2.5000,5.0000,0.0000` | `2.5000,0.0000,0.0000` | `2.5000` | MATCH |
| yaw +90° (Y) | `0.0000,1.0000,0.0000` | `1.0000,-0.0000,0.0000` | `-0.0000,5.0000,-2.5000` | `-0.0000,0.0000,-2.5000` | `2.5000` | MATCH |

**ทุกช่องเท่ากับ baseline §B.2 ทุกทศนิยม** รวมถึงสองพฤติกรรมที่ baseline ตรึงไว้ชัด ๆ:

- **roll ถูกตัดออก**: flat / roll 50° / roll 180° / yaw 90° → `UpVector` = **world up เป๊ะ** เพราะ
  `FOLLOW_UP = Vector3.yAxis` → เพ็ตยังตั้งตรงระดับพื้นแม้ผู้เล่นนั่งหรือ ragdoll คว่ำ 180°
- **pitch ยัง propagate เข้าเพ็ต** (`UpVector = 0,0.8192,0.5736` ที่ pitch 35°) — baseline บันทึกไว้ตรง ๆ ว่า
  **นี่คือพฤติกรรมเดิมของโค้ดปัจจุบัน ไม่ใช่บั๊กที่งานนี้แก้** และหลังแก้ต้องยังเป็นเท่านี้ →
  **เป็นเท่าเดิมจริง จึงไม่รายงานเป็น regression** (ถ้าจะเปลี่ยนต้องเป็นงานแยกที่ผู้ใช้สั่ง)
- **lerp residual จาก pivot ที่ผิด 180° = `153.0000°`** (= 180 × 0.85) เท่ากับ baseline เป๊ะ →
  ยังเป็น smooth lerp ไม่ใช่ snap

## §C — Multi-owner (3.4)

`src/server/Services/PetService.lua` **ไม่อยู่ในรายการไฟล์ที่ modified** ของ git → ไฟล์ identical กับ baseline
และบรรทัดสัญญายังอยู่ที่ตำแหน่งเดิมตามที่ baseline §C บันทึก:

| สัญญา baseline §C | บรรทัดที่พบตอนนี้ | ผล |
|---|---|---|
| `FireAllClients({ ownerUserId = player.UserId, equipped = true, egg, name })` ตอน equip (~395) | **396** | MATCH |
| `FireAllClients({ ownerUserId, equipped = false })` ตอน unequip (~417) | **417** | MATCH |
| `FireAllClients({ ownerUserId, equipped = true, … })` ตอน restore จาก profile (~433) | **434** | MATCH |
| backfill `FireClient(targetPlayer, { ownerUserId = ownerPlayer.UserId, … })` (~447) | **448** | MATCH |
| `FireAllClients({ ownerUserId, equipped = false })` ตอน `PlayerRemoving` (~640) | **640** | MATCH |

ฝั่ง client (`PetClient.client.lua`) ยังเป็น key ต่อเจ้าของเหมือนเดิม:
`activePets: { [ownerUserId]: { model, connection } }` · `despawnPet(ownerUserId)` disconnect Heartbeat +
`model:Destroy()` · `Players.PlayerRemoving:Connect(… despawnPet(leavingPlayer.UserId))` → **ลบถูกตัว**

## §D — Boost / ชื่อเพ็ต / rarity / gacha odds (3.5)

### คีย์ `PET_BOOSTS` ↔ ชื่อ Model: **1:1 ครบ ไม่มีขาดไม่มีเกิน**

เทียบชุดชื่อจาก §A (Model จริงในแต่ละ egg folder) กับตารางในซอร์ส:

| Egg | คีย์ใน `PET_BOOSTS` | Model ใน folder | ตรงกัน |
|---|---|---|---|
| Common Egg | Dog 5, Happy Dog 5, Dark Dog 6, White Cat 6, Black Cat 7, White Rabbit 7, Pink Rabbit 8 | 7 ตัว | ✔ **7/7** |
| Uncommon Egg | MewWat 13, Snow Cat 15 | 2 ตัว | ✔ **2/2** |
| Godly Egg | BoBo 30, Fireclouds 32, Thorney 34, Bluehoo 38 | 4 ตัว | ✔ **4/4** |
| Galactic Egg | Brownbear 50, Whitebear 53, Blackbear 56, PinkPig 59, GoldPig 62, Bluewing 65 | 6 ตัว | ✔ **6/6** |
| Divine Egg | Sun Flare 88, Moon 94, Moon Flare 100 | 3 ตัว | ✔ **3/3** |

**ค่า boost ทุกตัวเท่ากับ baseline §D ทุกตัวเลข** → `PET_BOOSTS` lookup ไม่พลาดแม้แต่ตัวเดียว
(`Evolved` เป็น Folder ไม่ใช่ Model ลูกตรง จึงไม่ทำให้มีคีย์เกิน — เหมือน baseline)

### ตารางอื่นใน `EconomyBalance.lua` — เท่าเดิมทุกค่า

| ตาราง | baseline | ตอนนี้ | ผล |
|---|---|---|---|
| `PET_BOOST_RANGES` | Common `{5,8}` · Uncommon `{12,18}` · Godly `{28,38}` · Galactic `{50,65}` · Divine `{85,100}` | **เท่ากันทุกค่า** | MATCH |
| `PET_GROWTH_REDUCTION` | Godly `BoBo 6, Thorney 10, Bluehoo 15` · Galactic `Bluewing 18` · Divine `Sun Flare 8, Moon Flare 12` | **เท่ากันทุกค่า** | MATCH |
| `EGGS` (gacha / ราคา / rarity) | Common 300 Common · Uncommon 1800 Uncommon · Godly 7500 Rare · Galactic 30000 Epic · Divine 120000 Legendary (Diamonds 100) | **เท่ากันทุกค่า** | MATCH |

`EconomyBalance.lua` **ไม่อยู่ในรายการ modified** ของ git → ไฟล์ identical กับ baseline ทั้งไฟล์

HUD (`src/client/hud/PetBoost.client.lua`) ยังเป็นสูตรเดิมคำต่อคำ:
`cashPct = math.max(0, math.floor((player:GetAttribute("PetBoost") - 1) * 100))` → `Pet Boost: +{cashPct}%`
และต่อท้าย ` · -{growPct}% grow` เมื่อ `PetGrowthReduction > 0`
→ ค่าบน HUD เป็นฟังก์ชันของ attribute ที่ server ตั้งจาก `PET_BOOSTS` เท่านั้น **ไม่เกี่ยวกับ orientation**

**profile data**: `DataService` / `PetService` ไม่ถูกแตะ และ **ชื่อเพ็ตทุกตัวคงเดิม 22/22** →
เพ็ตที่บันทึกอยู่ในโปรไฟล์เดิม (`data.EquippedPet.name` / `egg`) ยัง resolve เจอ Model และเจอคีย์ boost
→ ไม่มีเงื่อนไขใดที่จะทำให้โปรไฟล์ถูกรีเซ็ตหรือเพ็ตเดิมใช้ไม่ได้

## §E — Legacy fallback (3.6)

รัน logic `getFollowerRoot` / `getFacingAttachment` / `getLegacyFacingOffset` / `computeFollowTarget`
ชุดเดียวกับใน `PetClient.client.lua` กับ **Model ชั่วคราวที่ไม่เคย parent เข้า DataModel** แล้ว `:Destroy()` ทิ้ง
(วิธีเดียวกับ baseline §E — **ไม่มี pet asset จริงตัวใดถูกทำให้เสียหายเพื่อทดสอบ**)

| เคส | tier ที่ resolve ได้ | `facingCorrection.LookVector` | `target.LookVector` | baseline §E | ผล |
|---|---|---|---|---|---|
| A: ไม่มี `FollowerRoot`, `FacingOffsetY = 180` | **legacy** | `0.0000,-0.0000,1.0000` | `0.0000,-0.0000,1.0000` | `(0,−0,1)` | **MATCH — ยังพลิก 180° ทำงาน ✔** |
| B: ไม่มี `FollowerRoot`, ไม่มี attribute (รูปเดียวกับ `Evolved`) | legacy | `-0.0000,0.0000,-1.0000` | `-0.0000,0.0000,-1.0000` | identity | MATCH |
| C: ไม่มี `FollowerRoot`, `FacingOffsetDegrees = 180` | legacy | `0.0000,-0.0000,1.0000` | `0.0000,-0.0000,1.0000` | `(0,−0,1)` | **MATCH — alias path ทำงาน ✔** |
| D: มี `FollowerRoot` ไม่มี `FacingAttachment` (gen1) | gen1 | `-0.0000,-0.0000,-1.0000` | `-0.0000,-0.0000,-1.0000` | identity | MATCH |
| E: gen2 ด้วย `FacingAttachment.CFrame` ตัวจริงจาก asset | gen2 | `-0.0000,-0.0000,1.0000` | `-0.0000,-0.0000,1.0000` | `(−0,−0,1)` | MATCH (`target.Position = 2.5,5.0000,0`) |

ลำดับ 3 ชั้น `FacingAttachment → FollowerRoot identity → FacingOffset*` **ยังเป็นลำดับเดิม** (tier ที่ resolve
ได้ตรงกันทั้ง 5 เคส) → **3.6 ไม่ regress**

## §F — Build / repo state (3.7)

```
> rojo build --output %TEMP%\pet-facing-verify-task3.5.rbxl   (จาก repo root, default.project.json)
Building project 'FarmingRobloxSimulator'
Built project to pet-facing-verify-task3.5.rbxl
EXIT=0
```
**ผ่านสะอาด ไม่มี warning ไม่มี error** เท่ากับ baseline §F · temp `.rbxl` ถูกลบแล้ว (`Test-Path = False`)

หมายเหตุ: project file อยู่ที่ **repo root** ไม่ใช่ `src/` — task 3.3 §6 ยืนยันไว้แล้ว
ถ้อยคำ "รัน `rojo build` จาก `src/`" ใน requirement 3.7 หมายถึง *build source tree* ไม่ใช่ cwd

```
get_diagnostics  PetClient.client.lua / PetService.lua / EconomyBalance.lua / CalibratePetOrientation.lua
→ No diagnostics found (ทั้ง 4 ไฟล์)
```

### `git status --porcelain` เทียบกับ baseline §F

| ไฟล์ | baseline §F | ตอนนี้ | อธิบาย |
|---|---|---|---|
| `.kiro/settings/mcp.json` | ` M` | ` M` | เท่าเดิม |
| `default.project.json` | ` M` | ` M` | เท่าเดิม |
| `src/client/world/WeatherClient.client.lua` | ` M` | ` M` | เท่าเดิม |
| `src/shared/Modules/WeatherSounds.lua` | ` M` | ` M` | เท่าเดิม |
| `tools/IntegrateCropFromSelection.lua` | ` M` | ` M` | เท่าเดิม |
| `tools/IntegratePetsFromSelection.lua` | ` M` | ` M` | เท่าเดิม |
| `tools/MigrateNewFarmSoil.lua` | ` M` | ` M` | เท่าเดิม |
| `src/shared/Modules/RainVisualConfig.lua` | `??` | `??` | เท่าเดิม |
| `.kiro/specs/*` (3 โฟลเดอร์) | `??` | `??` | เท่าเดิม |
| `src/client/panels/PetClient.client.lua` | ` M` | **หายจากรายการ** | **commit `c51bd5e`** — งานที่ task 3.3 สั่งไว้ตรง ๆ |
| `tools/CalibratePetOrientation.lua` | `??` | **หายจากรายการ** | **commit `4fad98c`** — งานที่ task 3.1 สั่งไว้ตรง ๆ |

สองบรรทัดสุดท้ายคือ **การเปลี่ยนที่ตั้งใจและมีบันทึกไว้** (3.1 "commit ไฟล์นี้", 3.3 "commit ให้จบ")
ไม่ใช่ drift ที่หลุดมา · ไฟล์ modified ที่ไม่เกี่ยวข้อง **ไม่ถูกแตะเลยแม้แต่ไฟล์เดียว**

**ไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client**: `PetClient.client.lua` ยังทำแค่ resolve PetShop UI / toggle blur+HUD /
spawn-despawn follower ตาม `ownerUserId` ที่ server ส่งมา / เปิด UI ตอน `PetRollResult.success`
ไม่มีการตัดสินเงิน ราคา inventory หรือ ownership (ยืนยันจากการอ่านไฟล์ทั้งไฟล์ + `git show --stat` ใน task 3.3
ว่าแตะไฟล์เดียว) → **3.7 ไม่ regress**

## §G — รายการที่ต้องยืนยันด้วยตา

**ข้อจำกัดที่ต้องพูดตรง ๆ ไม่ทำให้ดูแข็งกว่าที่เป็น:** baseline §G บันทึก G2–G5 ไว้เป็น `⏳ รอยืนยัน`
คือ **ไม่มีบันทึกภาพ/ค่าก่อนแก้** ให้เทียบแบบ before/after จริง ดังนั้นสิ่งที่ยืนยันได้คือ
**"ตรงกับสัญญาในซอร์สที่บันทึกค่าไว้แล้วและพิสูจน์แล้วว่าไม่ถูกแตะ"** (§B ตัวเลขการวางตัว, §C สัญญา
multi-owner, §D ตาราง boost) — **ไม่ใช่ true before/after diff** ส่วน G1 เป็น before/after จริงเพราะมีบันทึกก่อนแก้

| # | ข้อ | baseline | ผลรอบนี้ | ความแข็งของหลักฐาน |
|---|---|---|---|---|
| G1 (3.1) | `White Cat` ทิศที่เห็น | **หน้าออก** (ยืนยันแล้ว task 1 §3) | **หน้าออก เท่าเดิม** (ผู้ใช้ยืนยันใน task 3.4 §3 มุมกล้องเดียวกัน) + checksum `7F3783E0` เท่าค่าก่อนแก้ | **before/after จริง** |
| G2 (3.2) | ทิศเพ็ต egg อื่น (`Snow Cat`, `BoBo`) | `⏳ รอยืนยัน` | ผู้ใช้ตอบ: **"ดีหมดแล้ว เหมือนทุกอย่างหมด"** → ทิศเท่าเดิม | ตา + checksum/`FacingAttachment` ไม่เปลี่ยน (§A) |
| G3 (3.3) | ขวา ~2.5 studs, สเกลเล็ก, ตามลื่น, ตั้งตรงตอนนั่ง | `⏳ รอยืนยัน` | ผู้ใช้ตอบ: **ดีหมด** | ตา + ตัวเลข §B.2 ตรงทุกทศนิยม |
| G4 (3.4) | 2 players เห็น follower ของกันครบ + หายถูกตัว | `⏳ รอยืนยัน` | ผู้ใช้ตอบ: **ดีหมด** | ตา + สัญญา §C ทุกบรรทัดตำแหน่งเดิม |
| G5 (3.5) | ค่า boost บน HUD | `⏳ รอยืนยัน` (คาด `White Cat` → `+6%`) | ผู้ใช้ตอบ **"ดีหมด"** แต่ **ไม่ได้ให้ตัวเลขเจาะจง** → บันทึกว่ายืนยันเชิงคุณภาพ ยังไม่มี readout ตัวเลขจริง | ตา (เชิงคุณภาพ) + `PET_BOOSTS`/สูตร HUD identical (§D) |

**คำตอบผู้ใช้คำต่อคำ**: *"ดีหมดแล้ว แต่เหมือนทุกอย่างหมด"* — ไม่ได้แต่งเติมนอกเหนือจากนี้
ค่า HUD เชิงตัวเลขยังไม่ถูกอ่านออกมาตรง ๆ ถ้าต้องการปิดช่องนี้ให้สนิท ให้อ่านค่าตอน task 4 (integration)

---

## สรุปผล task 3.5 — Property 2 ผ่านครบ ไม่มี regression

| ข้อ | Requirement | วิธีวัด (ชุดเดิมจาก task 2) | ผล |
|---|---|---|---|
| §A.1 §G1 | **3.1** White Cat ไม่ regress | checksum `7F3783E0` + part count 4/3 + `FacingAttachment` EXACT + ตายืนยัน | **PASS** |
| §A.0 §A.1 §A.2 | **3.2** เพ็ตทุกตัวทุก egg + `Evolved` | 22/22 field-by-field + 22/22 checksum + 8/8 Evolved | **PASS** |
| §B | **3.3** offset 2.5 / สเกล 0.75 / smooth lerp / ตั้งตรง | 5 สถานะตรงทุกทศนิยม + residual `153.0000°` | **PASS** |
| §C | **3.4** multi-owner | PetService identical + 5 call site ตำแหน่งเดิม + `activePets` keyed per owner + ตายืนยัน | **PASS** |
| §D | **3.5** boost / ชื่อ / rarity / gacha / profile | `PET_BOOSTS` 22/22 1:1 + 3 ตารางเท่าเดิมทุกค่า + สูตร HUD เดิม | **PASS** (G5 ตัวเลข HUD ยังไม่มี readout เจาะจง) |
| §E | **3.6** legacy fallback | 5 เคส tier + LookVector ตรงทั้งหมด (`FacingOffsetY`/`Degrees = 180` ยังพลิก 180°) | **PASS** |
| §F | **3.7** build สะอาด + ไม่ย้ายตรรกะมา client | `rojo build` EXIT=0 + diagnostics สะอาด 4 ไฟล์ + git diff อธิบายได้ครบ | **PASS** |

**EXPECTED OUTCOME ของ task 3.5 บรรลุแล้ว: ผ่านทั้งหมด เท่ากับ baseline ก่อนแก้ — ไม่พบ field ใดต่างเลย**

`F(X) = F'(X)` สำหรับทุก `X` ที่ `isBugCondition(X)` เป็นเท็จ (White Cat + เพ็ต egg อื่น 15 ตัว + Evolved 8 ตัว)
สิ่งเดียวที่เปลี่ยนในทั้ง place คือ **geometry ของ 6 ตัวที่ตั้งใจแก้** ตามที่ task 3.2 บันทึก และ 2 commit
ที่ task 3.1/3.3 สั่งไว้ตรง ๆ

**ไม่ถูกแตะระหว่าง task นี้** (verification-only): instance data ทุกตัว, `tools/CalibratePetOrientation.lua`,
`PetClient.client.lua`, `PetService`, `DataService`, `EconomyBalance`
`workspace.PetOrientationCalibration` ยังอยู่ครบ **6 station** — `ACTION = "CLEANUP"` เป็นงานของ task 4

**ขั้นถัดไป**: task 4 (integration + persistence รอบสุดท้าย + `CLEANUP`) — และตอนนั้นอ่านค่า HUD จริงเพื่อปิด G5

---

## ภาคผนวก — Runbook ใช้ซ้ำได้กับเพ็ตเทียร์อื่น/ตัวอื่นในอนาคต

(ผู้ใช้ขอให้เก็บวิธีนี้ไว้ เวลาเพ็ตตัวอื่นหันผิดจะได้ปรับหน้าได้เลย)

### สัญญาที่ต้องเข้าใจก่อน (แก้ Lua เฉย ๆ ไม่มีผล)

ทิศการหันอยู่ใน **instance data** ไม่ใช่โค้ด — `PetClient.client.lua` เลือก correction 3 ชั้นตอน spawn:

```lua
facingCorrection = FacingAttachment.CFrame:Inverse()   -- gen2 (มาตรฐานปัจจุบัน)
                 หรือ CFrame.new()                      -- gen1 (มี FollowerRoot ไม่มี attachment)
                 หรือ getLegacyFacingOffset(src)        -- legacy (FacingOffsetX/Y/Z / Degrees)
```

หน้าที่เห็น = ความสัมพันธ์ระหว่าง **geometry** กับ **`FacingAttachment`** ที่ bake ไว้ในโมเดล
→ ซ่อมด้วยการหมุน `Visuals` **ห้ามหมุน `FollowerRoot`** และ **ห้ามแตะ `FacingAttachment`**

### ขั้นตอน (สั้น)

1. **Edit mode** เท่านั้น · หนึ่ง Studio window · หนึ่ง place
2. **เก็บ baseline ก่อนแก้**: รันสคริปต์ checksum (`verification-task3.2.md` §6) + audit
   `FollowerRoot`/`PrimaryPart`/`FacingAttachment.CFrame`/attributes ของ **ทุกตัวในทุก egg** เก็บไว้เป็นไฟล์
   — เก็บ **สคริปต์ด้วย ไม่ใช่แค่ผลลัพธ์** (บทเรียนจาก baseline task 2 ที่ format หายไปจน reproduce ไม่ได้)
3. เลือกเฉพาะตัวที่ผิดใน Explorer → `tools/CalibratePetOrientation.lua` ตั้ง **`SCOPE = "SELECTED"`**
   (**ห้าม `"ALL"`** — จะลากตัวที่ดีอยู่แล้วเข้ามาด้วย)
4. `ACTION = "SETUP"` → หมุน `Visuals` ให้ **หน้าสัตว์ชี้ไปทางลูกบอลเหลือง (`FacingTip`, local +Z)** และตั้งตรง
5. `ACTION = "BAKE"` + `CONFIRM_BAKE = true` → อ่าน output ให้ครบทุกบรรทัด ต้องได้ `root=true face=0°`
   ไม่มี `error`/`warn` (guard จาก task 3.1 จะ error ถ้า geometry หันสวน attachment)
6. **Ctrl+S → ปิด place → เปิดใหม่ → query ซ้ำเอง** ห้ามรับคำว่า "เสร็จแล้ว" แบบเชื่อใจ
7. Play → ดูด้วยตาให้ครบ 8 สถานะ (เดินหน้า/ถอยหลัง/หมุนเร็ว/กระโดด/นั่ง/re-equip/respawn/รอบใหม่)
8. เทียบ checksum ของ **ตัวที่ไม่ได้แก้** ว่าเท่าเดิมทุกตัว แล้วจึง `ACTION = "CLEANUP"`

### กับดักที่เจอมาแล้ว (จะเจอซ้ำ)

- **`SETUP` เรียก `visuals:PivotTo(...)` ซึ่งลบ `relYaw` ของ asset ออกโดยปริยาย** → asset ที่ `relYaw = 0`
  อยู่แล้ว (เช่น `Dog`, mesh `2913594807`) จะ **ยังกลับด้าน** หลัง SETUP ต้องหมุน `Visuals` 180° รอบแกน Y
  ผ่านจุดศูนย์ของ `FollowerRoot` เอง แล้วเช็คว่า `FollowerRoot.CFrame` ไม่ขยับ
- **`relYaw` ดิบเทียบข้าม mesh family ไม่ได้** — แต่ละ mesh pack authored forward axis ไม่เหมือนกัน
  (`11727816xxx` vs `2913594807` vs `1461041563`) ตัวเลข `relYaw` จึงแบ่งตาม mesh ไม่ใช่ตามทิศที่ตาเห็น
  → **ต้องมีคนดูด้วยตาเสมอ อ่านจาก instance data ตัวเดียวไม่พอ**
- **`setupStation` สร้าง root `2×2×2` Neon เขียว** ไม่เท่ากับ asset จริง (`1×1×1` Plastic `163,162,165`)
  ตั้ง `Size`/`Material`/`Color`/`Reflectance` ให้เท่าตัวที่ดีอยู่แล้ว **ก่อน** BAKE ไม่งั้นได้ diff ที่ไม่จำเป็น
- **pitch ของ root ยัง propagate เข้าเพ็ต** (roll กับ yaw ถูกตัดด้วย `FOLLOW_UP = Vector3.yAxis`)
  นี่คือพฤติกรรมเดิม **ไม่ใช่ regression** อย่ารายงานผิด
- **`Evolved` subfolder เป็น legacy tier** (ไม่มี `FollowerRoot`, `PrimaryPart = Head`) และยังไม่มี code path
  ใด spawn มัน — **อย่า calibrate เข้าไปโดยไม่ตั้งใจ**
- ทดสอบ warn / legacy fallback ด้วย **transient Model ที่ไม่เคย parent เข้า DataModel** แล้ว `Destroy()`
  **ห้ามทำ asset จริงเสียหายเพื่อทดสอบ**
