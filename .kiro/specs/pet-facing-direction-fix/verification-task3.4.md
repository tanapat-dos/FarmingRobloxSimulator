# Task 3.4 — รันชุดตรวจ bug condition เดิมจาก task 1 ซ้ำ (Property 1)

ชุดตรวจ = **ชุดเดิม 4 ส่วนจาก `evidence-task1.md`** ไม่ได้เขียนชุดใหม่:
(1) instance tier audit, (2) geometry-vs-attachment, (3) play-test facing observation, (4) Output warn audit

Studio: **Edit mode** ตลอดทุก query, place `FarmingRobloxSimulator` (105263904115612), one window
clientId `d52e1cb2-dcea-4def-bb4d-87617e3d97d2` (เซสชันเดียวกับที่เปิด place ใหม่ตอนปิด task 3.2)
**ไม่ได้รัน `ACTION = "CLEANUP"`** — `Workspace.PetOrientationCalibration` ยังอยู่ครบ 6 station
(ตรวจแล้ว: `Common Egg__Dog`, `__Dark Dog`, `__Happy Dog`, `__White Rabbit`, `__Black Cat`, `__Pink Rabbit`)
งานนี้เป็น **verification เท่านั้น** — ไม่มี instance data / tool / source file ใดถูกแก้

---

## 1) Instance tier audit — ครบ 7 แถว (เทียบกับ evidence-task1 §1)

| Pet | tier | `PrimaryPart == FollowerRoot` | root size / material / color | root `LookVector` | `FacingAttachment` | `FacingOffset*` |
|---|---|---|---|---|---|---|
| `Dog` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(-0.000026, 0, -1.000000)` | ✔ | `{}` none |
| `Happy Dog` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(0, 0, -1.000000)` | ✔ | `{}` none |
| `Dark Dog` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(0, 0, -1.000000)` | ✔ | `{}` none |
| `White Cat` *(baseline)* | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(0, 0, -1.000000)` | ✔ | `{}` none |
| `Black Cat` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(-0.000026, 0, -0.999999)` | ✔ | `{}` none |
| `White Rabbit` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(0, 0, -1.000000)` | ✔ | `{}` none |
| `Pink Rabbit` | **gen2** | ✔ true | `1,1,1` / Plastic / `163,162,165` | `(0, 0, -1.000000)` | ✔ | `{}` none |

`FacingAttachment.CFrame` ของทั้ง 7 ตัว **เท่ากันทุก component** และเท่ากับ `baseline-task2.md` §A.0 เป๊ะ:

```
comps = [0.000000, 0.000000, 0.000000,
         -1.000000, 0.000000, -0.000000,
          0.000000, 1.000000,  0.000000,
          0.000000, 0.000000, -1.000000]
orient(deg) = (-0.000000, -179.999991, 0.000000)
look (root-local) = (0.000000, -0.000000, 1.000000)  → +Z
```

→ **2.4 PASS**: สัญญา calibration เดิมถูกใช้ครบทั้ง 7 ตัว (`FollowerRoot` เป็น `PrimaryPart` +
`FacingAttachment`) ไม่มีกลไก orientation ชุดที่สอง และไม่มี attribute `FacingOffset*` ค้างให้ซ้อนกัน
root ทั้ง 7 ตัวเหมือนกันหมดรวมทั้ง `Size`/`Material`/`Color` (diff ที่ task 3.2 §1 ข้อ 2 แก้ไว้ยังคงอยู่)

หมายเหตุ `-0.000026` ของ `Dog` / `Black Cat`: คือ **0.0015°** ซึ่ง evidence-task1 บันทึกเป็น `(0,0,−1)`
เท่ากัน — ต่ำกว่า tolerance `±10°` ของ 2.1 ราว 6,700 เท่า ไม่มีนัยเชิงการมองเห็น

## 2) Geometry-vs-attachment — พลิก 180° จริงทั้ง 6 ตัว, White Cat ไม่ขยับ

`relYaw` = yaw ของ visual part เทียบ `FollowerRoot` (`root.CFrame:Inverse() * part.CFrame`)

| Pet | part | mesh | relYaw **ก่อนแก้** (task 1 §2) | relYaw **ตอนนี้** | relPitch / relRoll | ผล |
|---|---|---|---|---|---|---|
| `Dog` | `Head` (`Part`+SpecialMesh) | `2913594807` | `0.00` | **`−180.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| `Happy Dog` | `Head` (MeshPart) | `11727816926` | `−180.00` | **`0.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| `Dark Dog` | `Head` | `11727816260` | `−180.00` | **`0.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| `Black Cat` | `Head` | `11727816559` | `−180.00` | **`0.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| `White Rabbit` | `Head` | `11727814769` | `−180.00` | **`0.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| `Pink Rabbit` | `Head` | `11727815843` | `−180.00` | **`0.00`** | `−0.00 / 0.00` | FLIPPED180 ✔ |
| **`White Cat`** | `Head` / `Stone` / `Inner` | `1461041563` / `1461044710` / `1461040253` | `0.00` / `−180.00` / `176.80` | **`0.00` / `−180.00` / `176.80`** | `−0.00 / 0.00` ทุก part | **SAME ✔ (3.1)** |

`White Cat.Head.relPos` ยัง `(−0.0001, −1.3443, 0.7149)` — หัวยังอยู่ฝั่ง `+Z` = ฝั่งหน้าของ attachment
เหมือน evidence-task1 §2 เป๊ะ (preservation witness ไม่ถูกแตะ)

**`relPitch` และ `relRoll` = 0 ทุก part ของทั้ง 7 ตัว** และ root ทุกตัวไม่ถูกหมุน → ฝั่งข้อมูลไม่มีการเอียง
หรือพลิกใด ๆ ถูกใส่เข้ามา นี่คือครึ่งที่วัดได้ของ `isLevel` (อีกครึ่งคือ `FOLLOW_UP = Vector3.yAxis`
ที่ verification-task3.3 §4 ยืนยันว่าไม่ถูกแตะ → base frame ยังตัด roll ออกเหมือน baseline §B.2)

### Checksum — reproduce ด้วยสคริปต์ใน verification-task3.2 §6 ตรงตัว

| Pet | checksum ที่วัดได้ตอนนี้ | ค่าใน task 3.2 §6 | ผล |
|---|---|---|---|
| `Black Cat` | `2A5B6215` | `2A5B6215` | MATCH |
| `Dark Dog` | `B0C27678` | `B0C27678` | MATCH |
| `Dog` | `C83DA768` | `C83DA768` | MATCH |
| `Happy Dog` | `07DE2E38` | `07DE2E38` | MATCH |
| `Pink Rabbit` | `DFC796B0` | `DFC796B0` | MATCH |
| `White Rabbit` | `1F5B87C0` | `1F5B87C0` | MATCH |
| **`White Cat`** | `7F3783E0` | `7F3783E0` | MATCH (= ค่าก่อนแก้) |

7/7 ตรง → **2.2 (ฝั่งข้อมูล) PASS**: geometry ที่ bake ไว้ยัง persist ข้ามเซสชัน Studio และไม่มี drift
เพิ่มเติมหลัง task 3.2 (สคริปต์ §6 reproduce ได้จริง ต่างจาก checksum ของ baseline task 2 ที่ format หายไป)

## 3) Play-test facing observation

ตัวนี้อ่านจาก instance data ไม่ได้ — `evidence-task1.md` §2 พิสูจน์แล้วว่า 6 ตัวมี visual part เดียวที่
`relPos ≈ (0,0,0)` ทิศหน้าฝังอยู่ใน mesh เอง และแต่ละ mesh pack authored forward axis ไม่เหมือนกัน
(`relYaw` ดิบจึงแบ่งตาม mesh family ไม่ใช่ตามทิศที่ตาเห็น) **ต้องให้คนดู** เหมือนที่ task 1 §3 ทำ

**ผู้ใช้ยืนยันจากรอบเล่นจริง**: Ctrl+S → ปิด place → เปิดใหม่ → Play → equip ทีละตัว
มุมกล้องเดียวกับ task 1 §3 (กล้องหลังตัวละคร เดินไปข้างหน้าตรง ๆ เทียบ `White Cat` ในมุมเดียวกัน)

คำตอบที่ได้: **"ทั้ง 7 ตัวหน้าออก + ตั้งตรง, ครบ 8 สถานะถูกหมด, Output เงียบ"**

| Pet | `facesForward` | `isLevel` | `angleTo(observedFacing(WhiteCat))` |
|---|---|---|---|
| `Dog` | **หน้าออก** ✔ | ตั้งตรง ✔ | เท่ากับ `White Cat` ในมุมเดียวกัน → ≤ 10° ✔ |
| `Happy Dog` | **หน้าออก** ✔ | ตั้งตรง ✔ | ≤ 10° ✔ |
| `Dark Dog` | **หน้าออก** ✔ | ตั้งตรง ✔ | ≤ 10° ✔ |
| `Black Cat` | **หน้าออก** ✔ | ตั้งตรง ✔ | ≤ 10° ✔ |
| `White Rabbit` | **หน้าออก** ✔ | ตั้งตรง ✔ | ≤ 10° ✔ |
| `Pink Rabbit` | **หน้าออก** ✔ | ตั้งตรง ✔ | ≤ 10° ✔ |
| **`White Cat`** | **หน้าออก** ✔ (เหมือน task 1 §3 / baseline §G1) | ตั้งตรง ✔ | baseline (0°) — **ไม่ regress (3.1)** |

**6/6 counterexample จาก task 1 พลิกจาก FAIL → PASS** และ preservation witness ยังผ่านเหมือนเดิม
→ `isBugCondition(X) = observedFacing(X) ≠ observedFacing(WhiteCat)` เป็น **เท็จทั้ง 7 ตัว** แล้ว
(task 1 บันทึกไว้ว่าเป็นจริง 6 ตัว) — **2.1, 2.3 PASS**

### ความคงที่ข้ามสถานะ (2.2)

ครบทั้ง 8 สถานะ **ทิศถูกหมด ไม่เสียในสถานะใดเลย**:
`เดินหน้า` ✔ · `ถอยหลัง` ✔ · `หมุนตัวเร็ว` ✔ · `กระโดด` ✔ · `นั่ง` ✔ · `re-equip` ✔ ·
`respawn` ✔ · `เข้าเกมรอบใหม่` ✔

ตรงข้ามกับ `bugfix.md` 1.2/1.3 ที่บันทึกไว้ว่าอาการ "ล็อกทิศกลับด้านไว้ทุกสถานะ ไม่หายเอง"
→ อาการหายจริง ไม่ใช่หายชั่วคราวตอน spawn — **2.2 PASS ครบทั้งฝั่งข้อมูลและฝั่งที่ตาเห็น**
(ยืนยันหลัง Ctrl+S → ปิด/เปิด place → Play ตามที่ 2.2 บังคับ ไม่ได้รับคำว่า "เสร็จแล้ว" แบบเชื่อใจ)

## 4) Output warn audit — requirement 2.5 ทั้งสองครึ่ง

รัน predicate ชุดเดียวกับใน `spawnPet` (`src/client/panels/PetClient.client.lua`) แบบคำต่อคำ

### ครึ่งที่ 1 — ไม่มี warn ค้างสำหรับ 7 ตัวนี้

| Pet | lookup ok | warns |
|---|---|---|
| `Dog` | ✔ | **NONE (silent)** |
| `Happy Dog` | ✔ | **NONE (silent)** |
| `Dark Dog` | ✔ | **NONE (silent)** |
| `White Cat` | ✔ | **NONE (silent)** |
| `Black Cat` | ✔ | **NONE (silent)** |
| `White Rabbit` | ✔ | **NONE (silent)** |
| `Pink Rabbit` | ✔ | **NONE (silent)** |

`staleWarnForAnyOf7 = false`

ความต่างจาก task 1 §4: ตอนนั้น "เงียบ **แล้วแสดงทิศผิด**" ซึ่ง 2.5 ห้าม — ตอนนี้เงียบเพราะ**ข้อมูลครบจริง**
(gen2 ครบ 7, `PrimaryPart` ถูก, attachment ครบ) ความเงียบจึงถูกต้องแล้ว **โดยมีเงื่อนไขว่าข้อ 3 ต้องผ่าน**

### ครึ่งที่ 2 — ยัง warn จริงเมื่อข้อมูลไม่ครบ

ทดสอบด้วย **transient Model ที่ไม่เคย parent เข้า DataModel** (เทคนิคเดียวกับ `baseline-task2.md` §E)
แล้ว `:Destroy()` ทิ้งทุกตัว — **ไม่มี pet asset จริงตัวใดถูกทำให้เสียหายเพื่อทดสอบ warn**

| เคส | รูปข้อมูล | warn ที่ยิง |
|---|---|---|
| A | มี `FollowerRoot`, ไม่มี `FacingAttachment` (gen1) | `missing FacingAttachment` ✔ |
| B | มี `FollowerRoot` + attachment แต่ `PrimaryPart = Head` | `PrimaryPart was not FollowerRoot` ✔ |
| C | `PrimaryPart` ผิด **และ** ไม่มี attachment | `PrimaryPart was not FollowerRoot` + `missing FacingAttachment` ✔ (ยิงทั้งคู่) |
| D | ไม่มี `BasePart` เลย | `has no BasePart` ✔ (แล้ว `Destroy` + return ไม่ crash) |
| E | `FindFirstChild("__NoSuchEgg__")` → `nil` | `Missing egg folder` ✔ |
| E | `FindFirstChild("__NoSuchPet__")` ใน `Common Egg` → `nil` | `Missing pet model` ✔ |

### ยืนยัน Output จริงตอน Play

ผู้ใช้ตรวจ F9/Output ตอน equip ทั้ง 7 ตัว: **"Output เงียบ"** — ไม่มีบรรทัด `[PetClient]` ใดโผล่เลย

→ **2.5 PASS ครบทั้งสองครึ่ง**: 7 ตัวเงียบ **และคราวนี้เงียบพร้อมทิศที่ถูก** (ต่างจาก task 1 §4 ที่เงียบ
แล้วแสดงผิด ซึ่ง 2.5 ห้ามไว้) ส่วนกลไก warn เองยังไม่ตาย — ยิงครบ 4/4 เมื่อข้อมูลไม่ครบจริง

## 5) Source / build (บริบท ไม่ใช่ scope หลักของ 3.4)

```
rojo build (repo root, default.project.json) → Built project ... EXIT=0
get_diagnostics src/client/panels/PetClient.client.lua → No diagnostics found
get_diagnostics tools/CalibratePetOrientation.lua      → No diagnostics found
```
temp `.rbxl` ที่สร้างเพื่อ build ถูกลบแล้ว

---

## สรุปผล task 3.4 — Property 1 ผ่านครบ

| Property 1 assertion | Requirement | วิธีวัด | ผล |
|---|---|---|---|
| `usesExistingCalibrationContract` | 2.4 | tier audit ครบ 7 (gen2 + `PrimaryPart` + attachment, ไม่มี `FacingOffset*`) | **PASS** |
| geometry พลิก 180° จริงทั้ง 6 | 2.1, 2.3 | `relYaw` ก่อน/หลัง | **PASS** |
| `facesForward` ทั้ง 6 ตัว | 2.1 | play-test ผู้ใช้ยืนยัน | **PASS** |
| `angleTo(observedFacing(WhiteCat)) ≤ 10°` | 2.1, 2.3 | play-test มุมกล้องเดียวกับ task 1 | **PASS** |
| `isLevel` (ข้อมูล + ที่ตาเห็น) | 2.1 | `relPitch`/`relRoll` = 0 + play-test | **PASS** |
| ทิศคงที่ 8 สถานะ | 2.2 | play-test (เดินหน้า/ถอยหลัง/หมุนเร็ว/กระโดด/นั่ง/re-equip/respawn/รอบใหม่) | **PASS** |
| `persistsAfterSaveAndReopen` | 2.2 | checksum 7/7 reproduce + Play หลังเปิด place ใหม่ | **PASS** |
| `White Cat` ไม่ regress | 2.3, 3.1 | checksum `7F3783E0` เท่าเดิม + ตายืนยัน | **PASS** |
| ไม่มี warn ค้างสำหรับ 7 ตัว | 2.5 | predicate ต่อ asset จริง + Output เงียบตอน Play | **PASS** |
| warn ยังดังเมื่อข้อมูลไม่ครบ | 2.5 | transient 6 เคส (4/4 warn) | **PASS** |

**EXPECTED OUTCOME ของ task 3.4 บรรลุแล้ว: ผ่านทั้ง 6 ตัว — บั๊กหายจริง**
`isBugCondition(X)` ที่ task 1 บันทึกว่าเป็นจริง 6 ตัว กลายเป็น **เท็จทั้ง 7 ตัว** โดยยังใช้สัญญา
calibration เดิม ไม่มีกลไก orientation ชุดที่สอง และไม่มีการแตะ preservation witness

สิ่งที่ **ไม่** ถูกแตะระหว่าง task นี้ (verification-only): instance data ทุกตัว,
`tools/CalibratePetOrientation.lua`, `PetClient.client.lua`, `PetService`, `DataService`, `EconomyBalance`
`Workspace.PetOrientationCalibration` ยังอยู่ครบ 6 station — `ACTION = "CLEANUP"` เป็นงานของ task 4

**ขั้นถัดไป**: task 3.5 (รันชุดตรวจ preservation จาก task 2 ซ้ำ) แล้วจึง task 4
