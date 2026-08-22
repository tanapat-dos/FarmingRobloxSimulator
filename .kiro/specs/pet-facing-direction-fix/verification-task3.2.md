# Task 3.2 — Re-calibrate Common Egg 6 ตัว (บันทึกผลและ checksum ชุดใหม่)

Studio: Edit mode ตลอดทุกการเขียน, place `FarmingRobloxSimulator` (105263904115612), one window
`SCOPE = "SELECTED"` (ไม่เคยใช้ `"ALL"`), `ACTION = "SETUP"` → `"BAKE"` + `CONFIRM_BAKE = true`
**ไม่ได้รัน `CLEANUP`** — `Workspace.PetOrientationCalibration` ยังอยู่ครบ (เป็นงานของ task 4)

---

## 1) Scope gate ก่อน BAKE

6 station เท่านั้น ไม่มี `White Cat` และไม่มีเพ็ต egg อื่น (`strayStations = []`)

| Station | FaceMarker offset (≥0.35) | dot กับ FacingTip | มุม | relYaw ใน station | root ถูกหมุน? | Visuals ตั้งตรง |
|---|---|---|---|---|---|---|
| Black Cat | 4.000 | +1.0000 | 0.0° | 0.00 | ไม่ | ✔ |
| Dark Dog | 3.000 | +1.0000 | 0.0° | 0.00 | ไม่ | ✔ |
| Dog | 3.000 | +1.0000 | 0.0° | −180.00 | ไม่ | ✔ |
| Happy Dog | 4.000 | +1.0000 | 0.0° | 0.00 | ไม่ | ✔ |
| Pink Rabbit | 5.000 | +1.0000 | 0.0° | 0.00 | ไม่ | ✔ |
| White Rabbit | 4.000 | +1.0000 | 0.0° | 0.00 | ไม่ | ✔ |

### สิ่งที่ต้องแก้เพิ่มระหว่างทาง (บันทึกไว้เพราะจะเกิดซ้ำได้)

1. **`Dog` เป็น station เดียวที่ยังกลับด้าน** (`dot = −1.0000`) ตอนผู้ใช้แจ้งว่าวาง marker เสร็จ
   สาเหตุ: `SETUP` เรียก `visuals:PivotTo(...)` ซึ่ง **ลบ `relYaw = −180°` ของ asset ออกโดยปริยาย**
   สำหรับ 5 ตัวที่ใช้ mesh pack `117278…` → 5 ตัวนั้นถูกพลิกให้ถูกเองตอน SETUP
   แต่ `Dog` ใช้ mesh เก่า `2913594807` ที่ `relYaw = 0` อยู่แล้ว → station เท่ากับ asset เป๊ะ = ยังผิด
   แก้โดยหมุน `Visuals` ของ station `Dog` 180° รอบแกน Y ผ่านจุดศูนย์ของ `FollowerRoot`
   (`FollowerRoot.CFrame` ไม่ขยับ ยืนยันด้วย `rootUntouched = true`, `FacingAttachment` ไม่ถูกแตะ)
2. **station helper root ไม่ตรงกับ asset root** — `setupStation` สร้าง root ขนาด `2×2×2` Neon สีเขียว
   แต่ `sanitizePart` แก้แค่ `Transparency` → ถ้า bake ทั้งอย่างนั้น เพ็ต 6 ตัวจะได้ root `2×2×2` Neon
   ต่างจาก `White Cat` (`1×1×1` Plastic `163,162,165`) ทั้งที่ task ต้องการให้ทั้ง 7 ตัวเหมือนกัน
   (ไม่มีผลเชิงฟังก์ชัน — root มองไม่เห็น ไม่ชน ไม่ query ไม่มีเงา — แต่เป็น diff ที่ไม่จำเป็น)
   แก้โดยตั้ง `Size` / `Material` / `Color` / `Reflectance` ของ station root ทั้ง 6 ให้เท่า `White Cat.FollowerRoot`
   ก่อน BAKE (`CFrame` ไม่ขยับ, `PrimaryPart` ยังเป็น root)

## 2) ผล BAKE (Output ของผู้ใช้ ครบทุกบรรทัด)

```
[PetCalibration] BAKED Common Egg     / Black Cat        root=true face=0° off FacingTip
[PetCalibration] BAKED Common Egg     / Dark Dog         root=true face=0° off FacingTip
[PetCalibration] BAKED Common Egg     / Dog              root=true face=0° off FacingTip
[PetCalibration] BAKED Common Egg     / Happy Dog        root=true face=0° off FacingTip
[PetCalibration] BAKED Common Egg     / Pink Rabbit      root=true face=0° off FacingTip
[PetCalibration] BAKE complete: 6 pet(s). Ctrl+S, then test manually before CLEANUP.
```
(บรรทัด `White Rabbit` อยู่ก่อน `BAKE complete` — รวม 6 บรรทัด `BAKED`)
ไม่มี `error` และไม่มี `warn` — guard geometry-vs-attachment จาก task 3.1 ผ่านทั้ง 6 ตัวที่ `face = 0°`

## 3) Fix verification — geometry พลิก 180° จริงทั้ง 6 ตัว

เทียบกับค่าก่อนแก้ที่ query ไว้ในเซสชันเดียวกัน (ไม่ใช่ค่าที่คาดเดา):

| Pet | `Head` relYaw ก่อนแก้ | หลังแก้ | ผล |
|---|---|---|---|
| Dog | 0.00 | −180.00 | FLIPPED180 ✔ |
| Happy Dog | −180.00 | 0.00 | FLIPPED180 ✔ |
| Dark Dog | −180.00 | 0.00 | FLIPPED180 ✔ |
| Black Cat | −180.00 | 0.00 | FLIPPED180 ✔ |
| White Rabbit | −180.00 | 0.00 | FLIPPED180 ✔ |
| Pink Rabbit | −180.00 | 0.00 | FLIPPED180 ✔ |
| **White Cat** | Head 0.00 / Stone −180.00 / Inner 176.80 | เท่าเดิมทั้ง 3 | **SAME ✔ (3.1)** |

ทั้ง 7 ตัวเป็น **gen2 เหมือนกัน**: `FollowerRoot` เป็น `BasePart` ลูกตรง + `Model.PrimaryPart == FollowerRoot`
+ `FacingAttachment` ครบ, root `Size = 1,1,1` / `Transparency = 1` / `Anchored` / `CanCollide = false`
/ `LookVector = (0,0,−1)` และ **ไม่มี attribute `FacingOffset*` ค้างเลย**
ชื่อเพ็ตครบทุกตัวทุก egg → `EconomyBalance.PET_BOOSTS` lookup ไม่พลาด (3.5)

## 4) Preservation verification

- `FacingAttachment.CFrame` ของ **ทั้ง 22 ตัว** เท่ากับ baseline §A.0 ทุก component
  (`0,0,0, −1,0,0, 0,1,0, 0,0,−1`, LookVector = +Z) — ไม่ถูกแตะแม้แต่ตัวเดียวตามที่กำหนด
- จำนวน BasePart ต่อตัวตรงกับ baseline §A.1 ครบ 22 แถว
- `Evolved` legacy Model **8 ตัว** ใน §A.2: ยังไม่มี `FollowerRoot`, `PrimaryPart = Head`,
  ไม่มี attribute — ไม่ถูก calibrate ไม่ถูกลบ ไม่ถูกเพิ่ม field (3.2, 3.6)
- checksum ของเพ็ต egg อื่นทั้ง 15 ตัว **ก่อน = หลัง BAKE = หลังเปิด place ใหม่**

### หมายเหตุเรื่อง checksum ของ baseline task 2

checksum ใน `baseline-task2.md` §A.1 **reproduce ไม่ได้** เพราะเอกสารบรรยายเฉพาะแนวคิด
(`name|class|relPos(4dp)|relOrientDeg(4dp)|size(4dp)` + FNV-1a 32-bit) แต่ไม่ได้เก็บสคริปต์ต้นฉบับไว้
ลอง 8 รูปแบบการจัดข้อความแล้วไม่มีอันไหนคืน `65F05218` ของ White Cat จึง **ไม่ใช้การเดา format**
แต่ใช้หลักฐานที่แข็งกว่าแทน: วัด checksum ด้วย algorithm เดียวกัน **ทั้งก่อนและหลัง** ในเซสชันนี้
โดย White Cat / Snow Cat / Moon มีค่าก่อน BAKE เก็บไว้จริง (คำนวณไว้ตอนหา format) และทั้งสามตัว
**ก่อน = หลัง** ซึ่งเป็น pre/post diff ตรงตัวบน preservation witness ที่สำคัญที่สุด

## 5) Persistence — Ctrl+S → ปิด place → เปิดใหม่ → query ซ้ำเอง

ยืนยันว่าเป็นเซสชันใหม่จริง: MCP `clientId` เปลี่ยนจาก `9eba4ebc-1c34-4693-9b80-ccbbcaa1ac88`
เป็น `d52e1cb2-dcea-4def-bb4d-87617e3d97d2` (ไม่ได้รับคำว่า "เสร็จแล้ว" แบบเชื่อใจ)

`persistenceProblems = NONE - all 7 persisted`

| Pet | gen2 | `Head` yaw | checksum หลังเปิดใหม่ | ตรงกับหลัง BAKE |
|---|---|---|---|---|
| Black Cat | true | 0.00 | `2A5B6215` | MATCH |
| Dark Dog | true | 0.00 | `B0C27678` | MATCH |
| Dog | true | −180.00 | `C83DA768` | MATCH |
| Happy Dog | true | 0.00 | `07DE2E38` | MATCH |
| Pink Rabbit | true | 0.00 | `DFC796B0` | MATCH |
| White Rabbit | true | 0.00 | `1F5B87C0` | MATCH |
| **White Cat** | true | 0.00 | `7F3783E0` | MATCH (= ค่าก่อนแก้) |

## 6) Checksum ชุดใหม่สำหรับ task 3.5 (reproducible)

algorithm ที่ใช้ — เดินซ้ำได้ตรงตัว:

```lua
-- ต่อ pet Model: ทุก BasePart ใน GetDescendants() ที่ไม่ใช่ FollowerRoot
local rel = root.CFrame:Inverse() * part.CFrame
local rx, ry, rz = rel:ToOrientation()
line = ("%s|%s|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f"):format(
	part.Name, part.ClassName,
	rel.Position.X, rel.Position.Y, rel.Position.Z,
	math.deg(rx), math.deg(ry), math.deg(rz),
	part.Size.X, part.Size.Y, part.Size.Z)
-- table.sort(lines) แล้ว fnv1a(table.concat(lines, "\n")) → ("%08X")
-- FNV-1a 32-bit: h = 2166136261; h = bxor(h, byte); h = (h * 16777619) % 2^32
```

| Egg | Pet | checksum (หลังแก้ / ยืนยันหลังเปิด place ใหม่) | อยู่ในชุดที่แก้? |
|---|---|---|---|
| Common Egg | Black Cat | `2A5B6215` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | Dark Dog | `B0C27678` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | Dog | `C83DA768` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | Happy Dog | `07DE2E38` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | Pink Rabbit | `DFC796B0` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | White Rabbit | `1F5B87C0` | ใช่ (เปลี่ยนแล้ว) |
| Common Egg | **White Cat** | `7F3783E0` | **ไม่ — ห้ามเปลี่ยน (3.1)** |
| Uncommon Egg | MewWat | `D11D1190` | ไม่ (3.2) |
| Uncommon Egg | Snow Cat | `F166FE08` | ไม่ (3.2) |
| Godly Egg | Bluehoo | `376999EB` | ไม่ (3.2) |
| Godly Egg | BoBo | `89D644F0` | ไม่ (3.2) |
| Godly Egg | Fireclouds | `8ACDC790` | ไม่ (3.2) |
| Godly Egg | Thorney | `03479EE0` | ไม่ (3.2) |
| Galactic Egg | Blackbear | `040EA878` | ไม่ (3.2) |
| Galactic Egg | Bluewing | `F1FD0150` | ไม่ (3.2) |
| Galactic Egg | Brownbear | `320F0E80` | ไม่ (3.2) |
| Galactic Egg | GoldPig | `A596576E` | ไม่ (3.2) |
| Galactic Egg | PinkPig | `04A63018` | ไม่ (3.2) |
| Galactic Egg | Whitebear | `1030D370` | ไม่ (3.2) |
| Divine Egg | Moon | `1F27A14C` | ไม่ (3.2) |
| Divine Egg | Moon Flare | `916888D8` | ไม่ (3.2) |
| Divine Egg | Sun Flare | `D6A916E8` | ไม่ (3.2) |

**22 แถว = ครบทุก pet Model ในทุก egg folder** (Common 7, Uncommon 2, Godly 4, Galactic 6, Divine 3)
หมายเหตุ: `baseline-task2.md` เขียน prose ว่า "23 pet Model" และ "11 `Evolved`" แต่ตาราง §A.1 มี 22 แถว
และ §A.2 มี 8 แถว — ตัวเลขในตารางถูก (7+2+4+6+3 = 22 และ 3+2+3 = 8) prose คลาดเอง ไม่มีข้อมูลหาย

---

## สรุปผล task 3.2

| ข้อ | เกณฑ์ | ผล |
|---|---|---|
| Scope | 6 station เท่านั้น ไม่มี White Cat / egg อื่น | **PASS** |
| BAKE | 6/6 `root=true face=0°` ไม่มี error/warn | **PASS** |
| Property 1 (2.1, 2.3) | geometry ทั้ง 6 พลิก 180° เทียบค่าก่อนแก้ | **PASS** |
| 2.4 | ใช้สัญญาเดิม gen2 ครบ 7 ตัว ไม่มีกลไก orientation ชุดที่สอง | **PASS** |
| Property 1 (2.2) | `persistsAfterSaveAndReopen` — ยืนยันในเซสชัน Studio ใหม่ | **PASS** |
| Preservation 3.1 | White Cat ทุก field + checksum เท่าเดิม | **PASS** |
| Preservation 3.2 | 15 เพ็ต egg อื่น + 8 `Evolved` เท่าเดิม | **PASS** |
| Preservation 3.5 | ชื่อเพ็ตครบทุก egg → `PET_BOOSTS` lookup ไม่พลาด | **PASS** |

**ยังค้างอยู่ (ไม่ใช่ขอบเขต task 3.2):** ยืนยันด้วยตาจากการเล่นจริงว่าทั้ง 6 ตัวหันหน้าออกแล้ว
(`facesForward`, `angleTo(WhiteCat) ≤ 10°`, `isLevel`) → task 3.4
และ `ACTION = "CLEANUP"` → task 4 หลังผ่าน play-test แล้วเท่านั้น

`tools/CalibratePetOrientation.lua` ถูกตั้งกลับเป็น `ACTION = "SETUP"` / `CONFIRM_BAKE = false`
เพื่อไม่ให้เผลอ bake ซ้ำจากการวางสคริปต์ลง Command Bar อีกครั้ง
