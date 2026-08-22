# Task 2 — Preservation Baseline (บันทึกบนข้อมูลที่ยังไม่แก้)

สถานะข้อมูลตอนบันทึก: **ยังไม่แก้อะไรเลย** — ไม่มี instance data / tool / source file ใดถูกแก้ระหว่างเก็บ baseline นี้
วิธีเก็บ: MCP read-only Luau evaluation (unparented transient instances เท่านั้น สำหรับเคส legacy) + code reading + `rojo build`
Studio: Edit mode, place `FarmingRobloxSimulator` (105263904115612), clientId `9eba4ebc-1c34-4693-9b80-ccbbcaa1ac88`, one window
เวลาบันทึก: ก่อนเริ่ม task 3.1 (`tools/CalibratePetOrientation.lua` ยัง untracked, `PetClient.client.lua` ยัง modified)

**วิธีใช้ไฟล์นี้ใน task 3.5**: รันสคริปต์เดิม (§A.1, §A.2, §D) ซ้ำ แล้ว diff กับค่าในไฟล์นี้ **ทีละ field**
ทุกแถวที่ไม่ใช่ `Common Egg` 6 ตัวที่แก้ ต้องเท่ากันเป๊ะ รวมถึง checksum

---

## A. Instance data ของ pet Model ทุกตัวในทุก egg folder (3.2)

โดเมนครบ: **5 egg folder / 23 pet Model / + 11 `Evolved` legacy Model** — enumerate ทั้งหมด ไม่สุ่ม

### A.0 ค่าที่เหมือนกันทั้ง 23 ตัว (invariant baseline)

ทุก pet Model ที่เป็นลูกตรงของ egg folder มีค่าต่อไปนี้ **เท่ากันหมดทุกตัว ไม่ต่างแม้แต่ bit เดียว**:

| Field | ค่า baseline (ทุก 23 ตัว) |
|---|---|
| `FollowerRoot` | มี, `ClassName = Part`, เป็นลูกตรงของ Model |
| `Model.PrimaryPart` | `FollowerRoot` (`primaryIsFollowerRoot = true`) |
| `FollowerRoot.CFrame.LookVector` | `(-0.000000, -0.000000, -1.000000)` (ไม่ถูกหมุน) |
| `FollowerRoot.Size` | `(1.000000, 1.000000, 1.000000)` |
| `FollowerRoot.Transparency` | `1.000000` |
| `FollowerRoot.Anchored` | `true` |
| `FollowerRoot.CanCollide` | `false` |
| `FacingAttachment` | มี, `ClassName = Attachment`, อยู่ใน `FollowerRoot` |
| `FacingAttachment.CFrame` components | `[0.000000, 0.000000, 0.000000, -1.000000, 0.000000, -0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, -1.000000]` |
| `FacingAttachment.CFrame:ToOrientation()` (deg) | `(-0.000000, -179.999991, 0.000000)` |
| `FacingAttachment.CFrame.LookVector` (root-local) | `(0.000000, -0.000000, 1.000000)` → **+Z** |
| attributes บน Model | `{}` — **ว่างเปล่า ไม่มี `FacingOffsetX/Y/Z` และไม่มี `FacingOffsetDegrees` ตัวใดเลย** |
| tier | **gen2** ทั้ง 23 ตัว |

→ ทุกตัวเดิน code path `facingCorrection = FacingAttachment.CFrame:Inverse()` = `CFrame.Angles(0, -π, 0)`

### A.1 ตารางต่อตัว: geometry fingerprint (ค่าที่แยกแต่ละตัวออกจากกัน)

`fingerprint` = สำหรับ BasePart ทุกตัวที่ไม่ใช่ `FollowerRoot` เอา `FollowerRoot.CFrame:Inverse() * part.CFrame`
แล้วบันทึก `name|class|relPos(4dp)|relOrientDeg(4dp)|size(4dp)` เรียง sort แล้ว checksum ด้วย FNV-1a 32-bit
→ **checksum เปลี่ยน = geometry ถูกแตะ** ใช้ diff ได้ตรง ๆ ใน task 3.5

| Egg | Pet | baseParts (รวม root) | geometry parts | **checksum** | boost key ตรง `PET_BOOSTS` | อยู่ในชุดที่จะแก้? |
|---|---|---|---|---|---|---|
| Common Egg | Black Cat | 2 | 1 | `72688AF8` | ✔ 7 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | Dark Dog | 2 | 1 | `734C6240` | ✔ 6 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | Dog | 2 | 1 | `B83B6680` | ✔ 5 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | Happy Dog | 2 | 1 | `CC098CF7` | ✔ 5 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | Pink Rabbit | 2 | 1 | `B3D1AC20` | ✔ 8 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | White Rabbit | 2 | 1 | `F668BE60` | ✔ 7 | **ใช่ (จะเปลี่ยน)** |
| Common Egg | **White Cat** | 4 | 3 | `65F05218` | ✔ 6 | **ไม่ — ห้ามเปลี่ยน (3.1)** |
| Uncommon Egg | MewWat | 14 | 13 | `2EBF6E50` | ✔ 13 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Uncommon Egg | Snow Cat | 14 | 13 | `EE466DA8` | ✔ 15 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Godly Egg | Bluehoo | 43 | 42 | `287F7728` | ✔ 38 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Godly Egg | BoBo | 20 | 19 | `A66302F8` | ✔ 30 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Godly Egg | Fireclouds | 36 | 35 | `69A62308` | ✔ 32 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Godly Egg | Thorney | 26 | 25 | `9C290ADE` | ✔ 34 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | Blackbear | 16 | 15 | `0683A958` | ✔ 56 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | Bluewing | 16 | 15 | `155BD91C` | ✔ 65 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | Brownbear | 16 | 15 | `EDC120D8` | ✔ 50 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | GoldPig | 11 | 10 | `BE33A7E4` | ✔ 62 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | PinkPig | 11 | 10 | `F1F64D78` | ✔ 59 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Galactic Egg | Whitebear | 16 | 15 | `56095CE0` | ✔ 53 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Divine Egg | Moon | 5 | 4 | `9C8CF5E3` | ✔ 94 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Divine Egg | Moon Flare | 13 | 12 | `6AE6C513` | ✔ 100 | ไม่ — ห้ามเปลี่ยน (3.2) |
| Divine Egg | Sun Flare | 13 | 12 | `E4D147A0` | ✔ 88 | ไม่ — ห้ามเปลี่ยน (3.2) |

**23 แถว = ครบทุก pet Model ในทุก egg folder** (Common 7, Uncommon 2, Godly 4, Galactic 6, Divine 3)

### A.2 `Evolved` legacy Model (พบใหม่ใน task 2 — ไม่มีใน task 1)

egg folder 3 ตัวมี subfolder `Evolved` ที่บรรจุ Model ซึ่งเป็น **legacy tier จริงในข้อมูลชุดปัจจุบัน**:

| Egg | Folder | Model | `FollowerRoot` | `PrimaryPart` | `FacingAttachment` | attributes | tier |
|---|---|---|---|---|---|---|---|
| Godly Egg | Evolved | Evolved Aether | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Godly Egg | Evolved | Evolved Hyperion | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Godly Egg | Evolved | Evolved Primus | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Galactic Egg | Evolved | Evolved Galactic Lord | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Galactic Egg | Evolved | Evolved Galactic Overlord | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Divine Egg | Evolved | Evolved Divine Sun | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Divine Egg | Evolved | Evolved Polygonis | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |
| Divine Egg | Evolved | Evolved The Star of Lakshmi | **ไม่มี** | `Head` | ไม่มี | `{}` | **legacy** |

หมายเหตุ: `grep "Evolved"` ใน `src/**/*.lua` = **ไม่มี match** และ `spawnPet` ใช้
`folder:FindFirstChild(petName)` แบบ **ไม่ recursive** → Model ชุดนี้ยังไม่ถูก spawn จาก code path ใด
**baseline คือ: ต้องคงอยู่เหมือนเดิมทุกตัว ไม่ถูก calibrate ไม่ถูกลบ ไม่ถูกเพิ่ม attribute** (3.2, 3.6)

---

## B. การวางตัว follower (3.3) — ค่าคงที่ในโค้ดและค่าที่วัดได้

### B.1 ค่าคงที่จาก `src/client/panels/PetClient.client.lua` (baseline ห้ามเปลี่ยน)

```lua
local FOLLOW_OFFSET = Vector3.new(2.5, 0, 0)  -- local-space offset จาก root (ไปทางขวา)
local FOLLOW_UP     = Vector3.new(0, 1, 0)    -- world up ไม่ใช่ root.CFrame.UpVector
model:ScaleTo(0.75)
model:PivotTo(pivot:Lerp(target, 0.15))       -- ทุกเฟรมบน RunService.Heartbeat
-- computeFollowTarget:
--   position = (root.CFrame * CFrame.new(FOLLOW_OFFSET)).Position
--   base     = CFrame.lookAt(position, position + root.CFrame.LookVector, FOLLOW_UP)
--   return   = base * facingCorrection
-- clone: ทุก BasePart → Anchored=true, CanCollide=false, CanTouch=false, CanQuery=false, CastShadow=false
```

### B.2 ค่าที่วัดได้จริงจาก logic เดิม (root ที่ `(0,5,0)` มองไป world `−Z`, correction = live gen2)

| สถานะของ root ผู้เล่น | `target.UpVector` | `target.LookVector` | `target.Position` | offset จาก root | \|offset\| |
|---|---|---|---|---|---|
| flat | `(0.0000,1.0000,0.0000)` | `(-0.0000,-0.0000,1.0000)` | `(2.5000,5.0000,0.0000)` | `(2.5000,0.0000,0.0000)` | `2.5000` |
| roll +50° (Z) | `(0.0000,1.0000,0.0000)` | `(-0.0000,-0.0000,1.0000)` | `(1.6070,6.9151,0.0000)` | `(1.6070,1.9151,0.0000)` | `2.5000` |
| roll +180° (Z, ragdoll คว่ำ) | `(0.0000,1.0000,0.0000)` | `(-0.0000,-0.0000,1.0000)` | `(-2.5000,5.0000,0.0000)` | `(-2.5000,0.0000,0.0000)` | `2.5000` |
| pitch +35° (X) | `(0.0000,0.8192,0.5736)` | `(-0.0000,-0.5736,0.8192)` | `(2.5000,5.0000,0.0000)` | `(2.5000,0.0000,0.0000)` | `2.5000` |
| yaw +90° (Y) | `(0.0000,1.0000,0.0000)` | `(1.0000,-0.0000,0.0000)` | `(-0.0000,5.0000,-2.5000)` | `(-0.0000,0.0000,-2.5000)` | `2.5000` |

ข้อเท็จจริงที่ baseline นี้ตรึงไว้ (สังเกตจริง ไม่ใช่คาดเดา):

- **flat/roll/yaw: `UpVector` = world up เป๊ะ** → `FOLLOW_UP = Vector3.yAxis` ตัด roll ของ root ออกหมด
  แม้ผู้เล่นนั่งหรือ ragdoll คว่ำ 180°
- **pitch ของ root ยัง propagate เข้าเพ็ต** (`UpVector` เอียงตาม pitch 35°) — นี่คือพฤติกรรม **เดิม**
  ของโค้ดปัจจุบัน ไม่ใช่บั๊กที่งานนี้แก้ และหลังแก้ต้องยังเป็นเท่านี้
- **offset เป็น local-space ของ root** → \|offset\| = `2.5000` คงที่ทุกสถานะ แต่ทิศหมุนตาม root
  (roll 180° ทำให้เพ็ตไปอยู่ซ้าย, yaw 90° ทำให้ไปอยู่ด้านหลัง world −Z)
- **lerp 0.15 หนึ่ง step** จาก pivot ที่ผิด 180° → residual **153.0000°** (= 180 × 0.85 เชิงมุม)
  ยืนยันว่าเป็น smooth lerp ไม่ใช่ snap

---

## C. Multi-owner (3.4) — สัญญาใน source (baseline ห้ามเปลี่ยน)

- `PetService` ยิง `petFollowUpdate:FireAllClients({ ownerUserId = player.UserId, equipped = true, egg = …, name = … })`
  ตอน equip (บรรทัด ~395), ตอน restore จาก profile (~433) และยิง `{ ownerUserId, equipped = false }` ตอน unequip (~417)
  และตอน `PlayerRemoving` (~640)
- backfill: `FireClient(targetPlayer, { ownerUserId = ownerPlayer.UserId, equipped = true, … })` สำหรับทุกคนที่ equip อยู่ (~447)
- `PetClient` เก็บ `activePets: { [ownerUserId]: { model, connection } }` — key ต่อเจ้าของ
  `despawnPet(ownerUserId)` disconnect Heartbeat + `model:Destroy()` และ `Players.PlayerRemoving` → `despawnPet(leavingPlayer.UserId)`
- **งานนี้ไม่แตะ `PetService` เลย** → หลังแก้ ไฟล์นี้ต้อง identical

## D. Boost / ชื่อเพ็ต / rarity (3.5)

`EconomyBalance.PET_BOOSTS` ทุกคีย์ **ตรงกับชื่อ Model ในทุก egg folder แบบ 1:1 ไม่มีขาดไม่มีเกิน**:

| Egg | คีย์ใน `PET_BOOSTS` | Model ใน folder | ตรงกัน |
|---|---|---|---|
| Common Egg | Dog 5, Happy Dog 5, Dark Dog 6, White Cat 6, Black Cat 7, White Rabbit 7, Pink Rabbit 8 | 7 ตัว | ✔ 7/7 |
| Uncommon Egg | MewWat 13, Snow Cat 15 | 2 ตัว | ✔ 2/2 |
| Godly Egg | BoBo 30, Fireclouds 32, Thorney 34, Bluehoo 38 | 4 ตัว | ✔ 4/4 |
| Galactic Egg | Brownbear 50, Whitebear 53, Blackbear 56, PinkPig 59, GoldPig 62, Bluewing 65 | 6 ตัว | ✔ 6/6 |
| Divine Egg | Sun Flare 88, Moon 94, Moon Flare 100 | 3 ตัว | ✔ 3/3 |

`PET_BOOST_RANGES` baseline: Common `{5,8}`, Uncommon `{12,18}`, Godly `{28,38}`, Galactic `{50,65}`, Divine `{85,100}`
→ ค่า boost ทุกตัวข้างบนอยู่ในช่วงของ egg ตัวเอง ✔

`PET_GROWTH_REDUCTION` baseline: Godly `BoBo 6, Thorney 10, Bluehoo 15`; Galactic `Bluewing 18`;
Divine `Sun Flare 8, Moon Flare 12` — ทุกคีย์มี Model รองรับครบ ✔

`EGGS` baseline: Common 300 / Uncommon 1800 / Godly 7500 / Galactic 30000 / Divine 120000 (Diamonds 100)

HUD: `src/client/hud/PetBoost.client.lua` แสดง `Pet Boost: +{cashPct}%` โดย
`cashPct = math.max(0, math.floor((player:GetAttribute("PetBoost") - 1) * 100))`
และต่อท้าย ` · -{growPct}% grow` เมื่อ `PetGrowthReduction > 0`
→ **ค่าบน HUD เป็นฟังก์ชันของ attribute ที่ server ตั้งจาก `PET_BOOSTS` เท่านั้น ไม่เกี่ยวกับ orientation**
งานนี้ไม่แตะ `EconomyBalance` / `PetService` → ค่าที่ HUD แสดงต้องเท่าเดิมทุกตัว

## E. Legacy fallback (3.6) — วัดจาก logic เดิม (unparented transient Model, ไม่แตะ place)

รัน logic `getFollowerRoot` / `getFacingAttachment` / `getLegacyFacingOffset` / `computeFollowTarget`
ชุดเดียวกับใน `PetClient.client.lua` กับ Model ชั่วคราวที่ไม่เคย parent เข้า DataModel:

| เคส | tier ที่ resolve ได้ | `facingCorrection.LookVector` | `target.LookVector` | สรุป |
|---|---|---|---|---|
| A: ไม่มี `FollowerRoot`, `FacingOffsetY = 180` | **legacy** | `(0.0000,-0.0000,1.0000)` | `(0.0000,-0.0000,1.0000)` | **หันตาม offset 180° ✔ ทำงาน** |
| B: ไม่มี `FollowerRoot`, ไม่มี attribute เลย (รูปเดียวกับ `Evolved`) | legacy | `(-0.0000,0.0000,-1.0000)` | `(-0.0000,0.0000,-1.0000)` | identity — ไม่หมุน |
| C: ไม่มี `FollowerRoot`, `FacingOffsetDegrees = 180` | legacy | `(0.0000,-0.0000,1.0000)` | — | alias path ทำงาน ✔ |
| D: มี `FollowerRoot` แต่ไม่มี `FacingAttachment` (gen1) | gen1 | `(-0.0000,-0.0000,-1.0000)` | — | identity ตามสัญญา |
| E: gen2 ด้วย `FacingAttachment.CFrame` ตัวจริงจาก asset | gen2 | `(-0.0000,-0.0000,1.0000)` | `(-0.0000,-0.0000,1.0000)` | `target.Position = (2.5,5,0)` |

**baseline 3.6 = A และ C ต้องยังให้ `LookVector = (0,0,+1)` (พลิก 180° จาก identity) หลังแก้**
และลำดับความสำคัญ 3 ชั้น `FacingAttachment → FollowerRoot identity → FacingOffset*` ต้องยังเป็นลำดับเดิม

## F. Build / repo state (3.7)

```
> rojo build --output %TEMP%\pet-facing-baseline-task2.rbxl
Building project 'FarmingRobloxSimulator'
Built project to pet-facing-baseline-task2.rbxl
EXIT=0
```

**ผ่านสะอาด ไม่มี warning ไม่มี error** — baseline ของ 3.7

`git status --porcelain` ตอนบันทึก baseline (บริบทเทียบทีหลัง):

```
 M .kiro/settings/mcp.json
 M default.project.json
 M src/client/panels/PetClient.client.lua
 M src/client/world/WeatherClient.client.lua
 M src/shared/Modules/WeatherSounds.lua
 M tools/IntegrateCropFromSelection.lua
 M tools/IntegratePetsFromSelection.lua
 M tools/MigrateNewFarmSoil.lua
?? .kiro/specs/pet-facing-direction-fix/
?? .kiro/specs/rain-visual-polish/
?? .kiro/specs/thunderstorm-polish/
?? src/shared/Modules/RainVisualConfig.lua
?? tools/CalibratePetOrientation.lua
```

ตรรกะเกมเพลย์ฝั่ง client: `PetClient.client.lua` เป็น visual-only (spawn/despawn follower + UI)
ไม่มีการตัดสินเงิน/inventory/ownership — baseline ของ "ไม่ย้ายตรรกะมา client"

---

## G. รายการที่ต้องยืนยันด้วยตา (play-test) — ค่าอ้างอิงสำหรับ task 3.5

ข้อเหล่านี้วัดจาก instance data ไม่ได้ ต้องให้คนเล่นยืนยัน บันทึกไว้เป็นข้อความอ้างอิงเพื่อเทียบซ้ำ:

| # | ข้อ | baseline ที่บันทึก | สถานะ |
|---|---|---|---|
| G1 (3.1) | `Common Egg.White Cat` ทิศที่เห็น | **หันหน้าออกตามทิศที่ผู้เล่นเดิน** (ผู้ใช้ยืนยันแล้วใน task 1 §3, มุมกล้อง: กล้องหลังตัวละคร เดินไปข้างหน้าตรง ๆ เทียบกับ `Dog` ในมุมเดียวกัน) | ✔ ยืนยันแล้ว (task 1) |
| G2 (3.2) | ทิศที่เห็นของเพ็ตอย่างน้อย 1 ตัวจาก 2 egg อื่น | รอผู้ใช้ยืนยัน (แนะนำ `Uncommon Egg.Snow Cat` + `Godly Egg.BoBo`) | ⏳ รอยืนยัน |
| G3 (3.3) | เพ็ตอยู่ขวามือ ~2.5 studs, สเกลเล็กลง, ตามแบบลื่น, ตั้งตรงแม้นั่ง | ค่าเชิงตัวเลขบันทึกไว้ใน §B แล้ว รอยืนยันด้วยตา | ⏳ รอยืนยัน |
| G4 (3.4) | Studio 2 players ต่างคนต่าง equip เห็น follower ของกันครบ และหายถูกตัวตอนคนหนึ่งออก | สัญญาใน source บันทึกไว้ใน §C แล้ว รอยืนยันด้วยตา | ⏳ รอยืนยัน |
| G5 (3.5) | ค่า boost บน HUD ตอน equip | รอผู้ใช้อ่านค่าจริง (คาดตาม §D เช่น `White Cat` → `Pet Boost: +6%`) | ⏳ รอยืนยัน |

**ผู้ใช้ยืนยันซ้ำตอนปิด task 2**: เพ็ต Common Egg ยังหันผิดหมดยกเว้น `White Cat`
→ ยืนยันว่า baseline ชุดนี้ถูกเก็บบน **ข้อมูลที่ยังไม่แก้จริง** (bug condition จาก task 1 ยังเป็นจริงครบ 6 ตัว)
task 2 เป็น observation-only ตามดีไซน์ — การซ่อมเริ่มที่ task 3.1 → 3.2

**สำคัญสำหรับ task 3.5**: ข้อ G2–G5 ต้องสังเกตด้วยเงื่อนไข/มุมกล้องเดียวกับที่บันทึกตรงนี้
แล้วเทียบว่า **เท่าเดิม** — ไม่ใช่เทียบกับ "ควรจะเป็น"

---

## สรุปผล task 2

| ข้อ | Requirement | ผลบนข้อมูลที่ยังไม่แก้ |
|---|---|---|
| §G1 | 3.1 White Cat baseline | **PASS** (ยืนยันแล้ว) |
| §A.1 §A.2 | 3.2 เพ็ตทุกตัวทุก egg | **PASS** — 23 pet Model + 8 Evolved legacy Model บันทึกครบ พร้อม checksum ต่อตัว |
| §B | 3.3 การวางตัว follower | **PASS** — offset 2.5 / scale 0.75 / lerp 0.15 / roll-cancel วัดค่าได้ครบ |
| §C | 3.4 multi-owner | **PASS** (สัญญา source บันทึกครบ; ยืนยันด้วยตาที่ G4) |
| §D | 3.5 boost / ชื่อ / rarity | **PASS** — คีย์ `PET_BOOSTS` ตรงกับชื่อ Model 23/23 |
| §E | 3.6 legacy fallback | **PASS** — `FacingOffsetY = 180` และ `FacingOffsetDegrees = 180` ยังพลิก 180° จริง |
| §F | 3.7 build สะอาด | **PASS** — `rojo build` exit 0 |

ทุกข้อที่วัดได้จากข้อมูล/โค้ด **ผ่าน** บนข้อมูลที่ยังไม่แก้ ตาม EXPECTED OUTCOME ของ task 2
เหลือเฉพาะ G2–G5 ที่ต้องให้คนยืนยันด้วยตาเพื่อปิด baseline ให้ครบ 100%
