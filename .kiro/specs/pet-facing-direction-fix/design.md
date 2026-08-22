# Pet Facing Direction Fix — Bugfix Design

## Overview

เพ็ต follower ของ **Common Egg** 6 จาก 7 ตัวหันกลับด้าน (~180°) มีเพียง **White Cat** ที่ถูก

ทิศการหันไม่ได้อยู่ใน Lua — `PetClient.client.lua` ไม่มีมุมของเพ็ตตัวใดเลย มันอ่าน **instance data** จาก
`ReplicatedStorage.Assets.Pets.<Egg>.<Pet>` ตอน spawn:

```lua
local facingCorrection = if sourceFacingAttachment
    then sourceFacingAttachment.CFrame:Inverse()   -- gen2: calibrated
    elseif sourceFollowerRoot then CFrame.new()    -- gen1: FollowerRoot only, ไม่มี attachment
    else getLegacyFacingOffset(src)                -- legacy: FacingOffsetX/Y/Z attributes
```

แล้ววาง `FollowerRoot.CFrame = base * facingCorrection` ทำให้ world frame ของ `FacingAttachment`
เท่ากับ `base` (frame ระดับพื้นของผู้เล่น) พอดี ทิศที่เห็นจึงเป็นผลของ **ความสัมพันธ์ระหว่าง geometry กับ
`FacingAttachment` ที่ถูก bake ไว้ในโมเดล** ไม่ใช่ผลของโค้ด

ดังนั้นแนวทางซ่อมคือ: **ตรวจ instance data ของเพ็ตทั้ง 7 ตัวก่อน** เพื่อแยกว่าแต่ละตัวอยู่ใน tier ไหน
(gen2 / gen1 / legacy) แล้วซ่อมด้วย `tools/CalibratePetOrientation.lua` ตามสัญญาเดิม — ไม่สร้างกลไก
orientation ชุดที่สอง — พร้อมแก้ข้อความชี้ทางใน tool ที่ขัดกันเองซึ่งน่าจะเป็นต้นเหตุที่ทำให้ bake กลับด้าน
สุดท้ายยืนยัน persistence ด้วยตัวเองหลัง Ctrl+S แล้วเปิด place ใหม่

## Glossary

- **Bug_Condition (C)**: `observedFacing(X) ≠ observedFacing(WhiteCat)` — เพ็ต `X` หันไม่ตรงกับ known-good baseline
- **Property (P)**: เพ็ตหันหน้าไปทางเดียวกับผู้เล่น คลาดไม่เกิน ~±10° ตั้งตรงระดับพื้น และ persist หลังบันทึก place
- **Preservation**: ทิศของ White Cat, ทิศของเพ็ต egg อื่น, การวางตำแหน่ง/สเกล/lerp, multi-owner follower, boost/rarity/profile data — ต้องไม่เปลี่ยน
- **`PetClient.client.lua`**: client script ใน `src/client/panels/` ที่ spawn/despawn follower และคำนวณ `facingCorrection` ตอน spawn — **ไม่ใช่จุดที่บั๊กอยู่**
- **`FollowerRoot`**: `BasePart` ลูกตรงของ pet Model ต้องเป็น `Model.PrimaryPart` ใช้เป็น pivot ของ follower (invisible, `Transparency = 1`)
- **`FacingAttachment`**: `Attachment` ใน `FollowerRoot` — `LookVector` = หน้าของ visual, `UpVector` = บน คือ **source of truth ของทิศ**
- **gen2 asset**: มีทั้ง `FollowerRoot` + `FacingAttachment` (สัญญาปัจจุบัน)
- **gen1 asset**: มี `FollowerRoot` แต่ **ไม่มี** `FacingAttachment` → runtime ได้ `facingCorrection = CFrame.new()` → หน้าเพ็ต = `FollowerRoot` local **−Z**
- **legacy asset**: ไม่มี `FollowerRoot` เลย → ใช้ attribute `FacingOffsetX/Y/Z` (หรือ `FacingOffsetDegrees`) เป็น fallback
- **`facingCorrection`**: `CFrame` ที่คำนวณครั้งเดียวตอน spawn แล้ว capture ไว้ใน closure ของ Heartbeat
- **`base`**: `CFrame.lookAt(pos, pos + root.LookVector, Vector3.yAxis)` — frame ระดับพื้นของผู้เล่น (สร้างใหม่จาก `LookVector` เพื่อกันการเอียงเวลานั่ง/ragdoll)

## Bug Details

### Bug Condition

บั๊กปรากฏเมื่อ spawn follower จาก pet Model ที่ instance data ของมัน **ไม่ได้นิยามทิศหน้าที่ถูกต้อง**
สาเหตุที่เป็นไปได้: (a) โมเดลไม่มี `FacingAttachment` (ยังเป็น gen1) จึงตกไปใช้ `FollowerRoot` local −Z
ทั้งที่ geometry ถูกจัดให้หันไป +Z, (b) โมเดลมี `FacingAttachment` แต่ตอน BAKE จัด `Visuals` หันกลับด้าน
จากทิศที่ attachment ระบุ, หรือ (c) โมเดลไม่มี `FollowerRoot` และ attribute `FacingOffset*` ที่เคยแก้ 180°
ถูกลบทิ้งไป

พื้นที่อินพุต `X` คือ pet Model แต่ละตัวใน `ReplicatedStorage.Assets.Pets.<Egg>`

**Formal Specification:**
```
FUNCTION isBugCondition(X)
  INPUT: X of type PetAssetModel (child of ReplicatedStorage.Assets.Pets.<Egg>)
  OUTPUT: boolean

  // ทิศ "หน้า" ที่เห็นจริงของ follower ที่ spawn จาก X
  // เทียบกับ White Cat ที่เป็น known-good baseline ในเงื่อนไขทดสอบเดียวกัน
  RETURN observedFacing(X) ≠ observedFacing(WhiteCat)

  // ตัวชี้วัดที่ตรวจได้จาก instance data (สาเหตุที่ทำให้ประโยคบนเป็นจริง):
  //   NOT hasFacingAttachment(X)            → gen1: correction = identity, หน้า = root −Z
  //   OR bakedGeometryOpposesAttachment(X)   → gen2 แต่ bake กลับด้าน
  //   OR (NOT hasFollowerRoot(X) AND legacyOffsetOf(X) = identity)
END FUNCTION
```

### Examples

- `Common Egg.Dog` — คาด: หน้าหมาชี้ไปทางที่ผู้เล่นเดิน / จริง: ก้นชี้ไปทางที่ผู้เล่นเดิน (~180°)
- `Common Egg.Happy Dog` — คาด: หน้าออก / จริง: กลับด้าน 180° เหมือนกัน
- `Common Egg.Dark Dog`, `Common Egg.Black Cat`, `Common Egg.White Rabbit`, `Common Egg.Pink Rabbit` — อาการเดียวกันทั้งหมด
- `Common Egg.White Cat` — คาด: หน้าออก / จริง: หน้าออก ✔ **ไม่เข้าเงื่อนไขบั๊ก** เป็น baseline
- Edge case: ผู้เล่นหมุนตัวหรือ re-equip — ทิศที่กลับด้านตามเพ็ตไปทุกครั้ง เพราะ `facingCorrection`
  ถูกคำนวณครั้งเดียวจาก instance data แล้ว lerp ไปหา target เดิมทุกเฟรม อาการจึงคงที่ ไม่ใช่ race
- Edge case: เพ็ต egg อื่น (Uncommon/Godly/Galactic/Divine) — สถานะทิศเป็นอย่างไรตอนนี้ ต้องคงเดิม
  ไม่ว่าจะถูกหรือผิดอยู่ (3.2) การซ่อมงานนี้จำกัดขอบเขตที่ Common Egg

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- `Common Egg.White Cat` ยังหันถูกเหมือนเดิม — ห้าม regress known-good witness (3.1)
- เพ็ตของ egg อื่น (Uncommon, Godly, Galactic, Divine ฯลฯ) ทิศเท่าที่เป็นอยู่ ไม่ถูกแก้โดยไม่ได้ตั้งใจ (3.2)
- การวางตัว follower: offset `Vector3.new(2.5, 0, 0)` ทางขวา, `ScaleTo(0.75)`, `Lerp(target, 0.15)`
  ทุกเฟรมบน Heartbeat, ตั้งตรงระดับพื้นเสมอเพราะ `base` สร้างจาก `FOLLOW_UP = Vector3.yAxis` (3.3)
- Multi-owner: spawn follower ให้ทุกผู้เล่นที่ equip ตาม `ownerUserId` และ `despawnPet` ถูกตัวตอน
  `PlayerRemoving` (3.4)
- `EconomyBalance.PET_BOOSTS` / `PET_BOOST_RANGES` / ชื่อเพ็ต / rarity / gacha odds / profile data
  ของผู้เล่นไม่เปลี่ยน — ชื่อเพ็ตใน egg folder ต้องตรงกับตาราง PET_BOOSTS ตัวเดิมทุกตัว (3.5)
- legacy fallback `FacingOffsetX/Y/Z` / `FacingOffsetDegrees` ยังทำงานสำหรับ asset ที่ยังไม่ calibrate (3.6)
- `rojo build` จาก `src/` ผ่านสะอาด และไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client (3.7)
- warn เดิมใน `PetClient` (`PrimaryPart was not FollowerRoot`, `missing FacingAttachment`,
  `has no BasePart`, `Missing pet model`) ยังคงอยู่และยังดังเมื่อข้อมูลไม่ครบ (2.5)

**Scope:**
อินพุตทั้งหมดที่ **ไม่** เข้าเงื่อนไข `isBugCondition` ต้องไม่ถูกกระทบเลย ได้แก่:
- `Common Egg.White Cat`
- pet Model ทุกตัวใน egg folder อื่น
- โค้ดเส้นทางอื่นของ `PetClient` ทั้งหมด: PetShop UI, blur/HUD toggle, `PetRollResult`,
  `TogglePetShop`, การ despawn ตอนถอดเพ็ต
- ฝั่ง server ทั้งหมด (`PetService`, `DataService`) — งานนี้ไม่แตะ server เลย

**Note:** พฤติกรรมที่ถูกต้องที่ต้องได้หลังแก้ นิยามไว้ใน Correctness Properties (Property 1)
หัวข้อนี้ว่าด้วยสิ่งที่ **ห้ามเปลี่ยน**

## Hypothesized Root Cause

จากการอ่านโค้ดจริง สาเหตุที่เป็นไปได้เรียงตามน้ำหนักหลักฐาน:

1. **ข้อความชี้ทางใน `CalibratePetOrientation.lua` ขัดกันเอง → bake กลับด้าน 180°** (น่าจะเป็นตัวหลัก)
   - ใน `setupStation` ตัวชี้ทางถูกวางที่ local **+Z**: `FacingGuide` ที่ `CFrame.new(0, …, 5)` และ
     `FacingTip` ที่ `CFrame.new(0, …, 9)` — ขณะที่ `FollowerRoot.CFrame` ไม่ถูกหมุน ทำให้ `LookVector` = −Z
     ตัวชี้ทางจึงอยู่ **ด้านหลัง** root
   - `FacingAttachment.CFrame = CFrame.Angles(0, math.pi, 0)` → `LookVector` = **+Z** = ชี้ไปทาง guide ✔
     ตรงกับ comment หัวไฟล์ "face the yellow endpoint of the red guide (+Z)"
   - แต่ `setup()` **print ออกมาว่า** `"make it upright and face the red -Z marker"` — **ขัดกับ geometry**
     ใครทำตามข้อความที่ print จะหมุน `Visuals` กลับด้านพอดี 180° ซึ่งคือขนาดความคลาดที่รายงานมาเป๊ะ
   - `bakeStation` ตรวจแค่ว่า `FollowerRoot` ไม่ถูกหมุน (`LookVector·(0,0,−1) ≥ 0.999`) — **ไม่มีการตรวจว่า
     geometry หันไปทาง attachment หรือกลับทาง** ความผิดนี้จึงผ่าน self-check ไปได้เงียบ ๆ

2. **เพ็ต 6 ตัวยังเป็น gen1 (มี `FollowerRoot` แต่ไม่มี `FacingAttachment`)**
   - snapshot เก่า `.sync-temp/orientation-validation.rbxlx` มี `PetClient` เวอร์ชันที่เขียนว่า
     *"FollowerRoot is the Model.PrimaryPart, with -Z as visual forward"* — คือ **สัญญา gen1** ไม่มี attachment
     ส่วน `pet-facing-validation.rbxlx` / `pet-facing-final-validation.rbxlx` เป็นสัญญา gen2 แล้ว
     ยืนยันว่ามีการเปลี่ยนสัญญากลางทาง
   - ถ้า asset ยังเป็น gen1: `facingCorrection = CFrame.new()` → หน้าเพ็ต = root local **−Z** แต่ gen2 จัด
     geometry ให้หันไป **+Z** → กลับด้าน 180° พอดี
   - เข้ากับ "White Cat ตัวเดียวถูก" ถ้า White Cat เป็นตัวทดลอง bake gen2 ตัวแรกแล้วงานค้างไว้
     (`tools/CalibratePetOrientation.lua` ยัง untracked, `PetClient.client.lua` ยัง modified ไม่ commit)

3. **legacy `FacingOffset*` ที่แก้ 180° อยู่ ถูกลบทิ้งระหว่าง bake**
   - ทั้ง `CalibratePetOrientation` (`LEGACY_ATTRIBUTES`) และ `IntegratePetsFromSelection` **strip**
     `FacingOffsetX/Y/Z` / `FacingOffsetDegrees` ตอนสร้าง replacement
   - ถ้าเพ็ตตัวใดเคยพึ่ง `FacingOffsetY = 180` แล้วถูก bake ครึ่งทาง (attribute หาย แต่ geometry ไม่ถูกจัดใหม่)
     `getLegacyFacingOffset` จะคืน identity → มองเห็นเป็น 180° กลับด้าน

4. **`Model.PrimaryPart` ไม่ใช่ `FollowerRoot`** — **ตัดออกว่าเป็นต้นเหตุของ 180°**
   `spawnPet` ตั้ง `model.PrimaryPart = followerRoot` ให้ clone อยู่แล้ว (พร้อม warn) จึงไม่ทำให้ทิศพลิก
   ยังต้องตรวจไว้เพราะเป็นสัญญาณว่าโมเดลผ่านมือ tool ที่ผิด

5. **DOM/timing** — **ตัดออก** `facingCorrection` คำนวณจาก `src` (asset ต้นฉบับ ไม่ใช่ clone) ตอน spawn
   และ closure จับค่าไว้คงที่ อาการที่ "ไม่หายเอง ไม่ขึ้นกับกล้อง" ตรงกับข้อมูลนิ่ง ไม่ใช่ race condition

Hypothesis 1 กับ 2 แยกจากกันได้ด้วยการ query instance เดียว: ถ้า 6 ตัวนั้น **ไม่มี** `FacingAttachment` →
สาเหตุคือ 2; ถ้า **มี** ครบทั้ง 7 ตัวเหมือนกัน → สาเหตุคือ 1 (geometry ถูก bake กลับด้าน)

## Correctness Properties

Property 1: Bug Condition — เพ็ต Common Egg ที่หันกลับด้านต้องหันหน้าออก

_For any_ pet Model `X` ที่เข้าเงื่อนไขบั๊ก (`isBugCondition(X)` เป็นจริง) follower ที่ spawn จาก `X`
หลังแก้ SHALL หันหน้าไปทางเดียวกับที่ผู้เล่นหันหน้า คลาดจาก `observedFacing(WhiteCat)` ไม่เกิน ~10°
SHALL ตั้งตรงระดับพื้น (ไม่เอียง ไม่พลิก) SHALL คงทิศนี้ไว้ตลอดการเดิน หมุนตัว re-equip respawn และเข้าเกมรอบใหม่
และ SHALL ยังถูกต้องหลังบันทึก place แล้วเปิดใหม่ (persistence ตรวจซ้ำเอง ไม่รับคำว่าเสร็จแบบเชื่อใจ)
โดยยังใช้สัญญา calibration เดิม (`FollowerRoot` เป็น `PrimaryPart` + `FacingAttachment`) ไม่มีกลไก
orientation ชุดที่สอง และเมื่อข้อมูลไม่ครบ SHALL warn ให้เห็นใน Output แทนการเงียบ

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

Property 2: Preservation — ทุกอินพุตที่ไม่ใช่บั๊กต้องเหมือนเดิม

_For any_ pet Model `X` ที่ **ไม่** เข้าเงื่อนไขบั๊ก (`isBugCondition(X)` เป็นเท็จ — คือ White Cat และเพ็ตของ
egg อื่นทุกตัว) พฤติกรรมหลังแก้ SHALL เท่ากับก่อนแก้ (`F(X) = F'(X)`) โดยรักษาทิศเดิม การวางตำแหน่ง
offset 2.5 ทางขวา สเกล 0.75 การ lerp แบบ smooth การตั้งตรงระดับพื้น การ spawn/despawn ตาม
`ownerUserId` ค่า pet boost / rarity / gacha odds / profile data legacy `FacingOffset*` fallback
และ `rojo build` จาก `src/` ที่ยังผ่านสะอาดโดยไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

การซ่อมหลักอยู่ที่ **instance data ใน place** ไม่ใช่ `src/` — เหมือนกรณี `SeedData` ที่แก้ Lua เฉย ๆ ไม่มีผล
ส่วนที่แก้ในไฟล์คือ tool ที่ทำให้เกิดความผิดพลาดซ้ำได้

**File**: `tools/CalibratePetOrientation.lua` (ยัง untracked — ต้อง commit พร้อมงานนี้)

1. **แก้ข้อความชี้ทางที่ขัดกันเอง (กันบั๊กเกิดซ้ำ)**
   - `setup()` print ปัจจุบัน: `"face the red -Z marker"` → ต้องพูดตรงกับ geometry ว่าให้หัน **หน้า**
     ของสัตว์ไปทาง **ลูกบอลเหลือง (`FacingTip`)** ปลายแท่งแดง ซึ่งอยู่ที่ local **+Z**
   - ให้ข้อความใน header comment, ข้อความใน `setup()` และตำแหน่ง guide เล่าเรื่องเดียวกันทั้งหมด

2. **เพิ่ม guard ตอน BAKE ให้ตรวจว่า geometry หันไปทาง attachment จริง**
   - ใน `bakeStation` เทียบทิศ "หน้า" ของ `Visuals` กับ `stationFacing.WorldCFrame.LookVector`
     ถ้า dot < 0 = กลับด้าน → `error` พร้อมบอกว่าต้องหมุน `Visuals` 180° ไม่ใช่หมุน `FollowerRoot`
   - ปัจจุบัน bake ตรวจแค่ว่า `FollowerRoot` ไม่ถูกหมุน จึงปล่อยความผิด 180° ผ่านไปเงียบ ๆ

3. **ให้ SETUP รายงาน tier ของแต่ละ asset ก่อนแก้**
   - print ต่อ station ว่าปัจจุบัน asset นั้นเป็น gen2 (`FollowerRoot` + `FacingAttachment`) / gen1
     (root แต่ไม่มี attachment) / legacy (ไม่มี root, มี `FacingOffset*` เท่าไร)
   - ทำให้แยก Hypothesis 1 กับ 2 ได้จาก output โดยไม่ต้องเดา และเป็นหลักฐานตั้งต้นของ exploratory step

**File**: `ReplicatedStorage.Assets.Pets["Common Egg"]` (instance data ใน place — งานหลัก)

4. **Re-calibrate 6 ตัวที่ผิด ด้วยสัญญาเดิม**
   - เลือกเฉพาะ `Dog`, `Happy Dog`, `Dark Dog`, `Black Cat`, `White Rabbit`, `Pink Rabbit`
     (`SCOPE = "SELECTED"` — **ห้ามใช้ `SCOPE = "ALL"`** เพราะจะลาก White Cat และเพ็ต egg อื่นเข้ามาด้วย
     ซึ่งเสี่ยง regress 3.1/3.2 โดยตรง)
   - `ACTION = "SETUP"` → หมุน `Visuals` ของแต่ละ station ให้ **หน้าชี้ไปทางลูกบอลเหลือง** และตั้งตรง
     ห้ามหมุน `FollowerRoot`
   - `ACTION = "BAKE"` + `CONFIRM_BAKE = true` → อ่าน self-check ให้ครบทุกบรรทัด
   - `ACTION = "CLEANUP"` **หลัง** ยืนยันด้วยการเล่นจริงแล้วเท่านั้น
   - ผลลัพธ์: ทั้ง 7 ตัวเป็น gen2 เหมือนกัน — ชื่อเพ็ตทุกตัวคงเดิมเพื่อไม่ให้ `PET_BOOSTS` lookup พลาด (3.5)

**File**: `src/client/panels/PetClient.client.lua`

5. **ไม่แก้ตรรกะ orientation** — สามชั้น (`FacingAttachment` → `FollowerRoot` identity → legacy
   `FacingOffset*`) ถูกต้องแล้วและครอบคลุม 2.4/3.6 ตามที่เป็น
   - ไฟล์นี้ยัง modified ไม่ commit → **ตรวจ diff แล้ว commit ให้จบ** เพื่อไม่ให้ Studio กับ `src/` หลุดกัน
   - ถ้าจะเพิ่มอะไร ให้เพิ่มได้แค่ warn ที่ช่วยตรวจ 2.5 ไม่ใช่คำนวณมุมเพิ่ม

**สิ่งที่ห้ามแตะ**: `PetService`, `DataService`, `EconomyBalance` (`PET_BOOSTS`, `PET_BOOST_RANGES`,
`PET_GROWTH_REDUCTION`), pet Model ของ egg อื่น และ Workspace source models

## Testing Strategy

### Validation Approach

สองเฟส: เฟสแรกเก็บ counterexample จากโค้ด/ข้อมูล **ก่อนแก้** เพื่อยืนยันหรือหักล้าง root cause
เฟสสองยืนยันว่าแก้แล้วถูกและไม่ทำของเดิมพัง

repo นี้ **ไม่มี automated test framework** — property ทั้งสองข้อตรวจด้วยมือ: `rojo build` ยืนยัน source,
MCP instance query ยืนยัน instance data + persistence, Studio play-test ยืนยันสิ่งที่ตาเห็น
ทุกหัวข้อทดสอบข้างล่างเป็น **checklist ที่คนรัน** ไม่ใช่ test case ที่รันเองได้

### Exploratory Bug Condition Checking

**Goal**: หา counterexample ที่แสดงบั๊กบนโค้ด/ข้อมูล **ที่ยังไม่แก้** เพื่อยืนยันหรือหักล้าง Hypothesized
Root Cause ถ้าหักล้างได้ ต้องกลับไปตั้งสมมติฐานใหม่ก่อนแก้อะไร

**Test Plan**: ก่อนแตะ instance ใด ๆ ให้ query instance data ของเพ็ต Common Egg ทั้ง 7 ตัว แล้วเทียบ
White Cat กับอีก 6 ตัว เพื่อดูว่า **ต่างกันตรงไหนจริง ๆ** — จุดนี้ตัดสินว่า Hypothesis 1 หรือ 2 เป็นตัวจริง
จากนั้นเล่นจริงเพื่อบันทึกสิ่งที่ตาเห็นและ warn ใน Output

**Test Cases**:
1. **Instance tier audit** — MCP query แต่ละตัวใน `ReplicatedStorage.Assets.Pets["Common Egg"]`:
   `FollowerRoot` มีไหม, `PrimaryPart == FollowerRoot` ไหม, `FacingAttachment` มีไหม + `CFrame` เท่าไร,
   attribute `FacingOffset*` เหลืออยู่ไหม — คาดว่า White Cat ต่างจากอีก 6 ตัวอย่างชัดเจน (จะล้มบน 6 ตัว)
2. **Geometry-vs-attachment direction** — เทียบทิศหน้าของ geometry กับ
   `FacingAttachment.WorldCFrame.LookVector` ของแต่ละตัว ถ้า dot < 0 → ยืนยัน Hypothesis 1 (bake กลับด้าน)
   (จะล้มบน 6 ตัว)
3. **Play-test baseline** — Edit mode → Ctrl+S → Play → equip Dog แล้วเดินไปข้างหน้า สังเกตว่าก้นออก
   ถ่ายเทียบกับ White Cat ในมุมกล้องเดียวกัน (จะล้มบน 6 ตัว)
4. **Output warn audit** — ดู F9/Output ตอน equip ทั้ง 7 ตัวว่ามี `[PetClient] Calibrated pet is missing
   FacingAttachment` หรือ `PrimaryPart was not FollowerRoot` โผล่ตัวไหน — ถ้ามี = Hypothesis 2 (gen1)
   ถ้าเงียบทั้ง 7 = Hypothesis 1 (2.5 บอกว่าห้ามเงียบแล้วแสดงผิด)
5. **Edge case: egg อื่น** — บันทึกทิศปัจจุบันของเพ็ต Uncommon/Godly อย่างน้อย 1 ตัวไว้เป็น baseline
   ของ preservation ก่อนแก้ (อาจผ่านหรือไม่ผ่านอยู่แล้ว — สิ่งสำคัญคือ "เท่าเดิม")

**Expected Counterexamples**:
- `Dog`, `Happy Dog`, `Dark Dog`, `Black Cat`, `White Rabbit`, `Pink Rabbit` หันกลับด้าน ~180°
  ขณะที่ `White Cat` ถูก ในเงื่อนไขเดียวกัน
- Possible causes: ข้อความชี้ทางใน SETUP ขัดกับ geometry ทำให้ bake กลับด้าน (1), asset ยังเป็น gen1
  ไม่มี `FacingAttachment` (2), attribute `FacingOffset*` ที่แก้ 180° ถูก strip ไปตอน bake (3)

### Fix Checking

**Goal**: ยืนยันว่าทุกอินพุตที่เข้าเงื่อนไขบั๊ก ให้พฤติกรรมที่ถูกต้องหลังแก้

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := spawnFollower_fixed(X)
  ASSERT facesForward(result)                          // หน้าออก ไม่ใช่ก้นออก
  ASSERT angleTo(result, observedFacing(WhiteCat)) <= 10°
  ASSERT isLevel(result)                               // ไม่เอียง ไม่พลิก
  ASSERT usesExistingCalibrationContract(X)            // FollowerRoot + FacingAttachment เท่านั้น
  ASSERT persistsAfterSaveAndReopen(X)
END FOR
```

โดเมนของ `X` ที่ต้องเดินให้ครบคือ 6 ตัว: `Dog`, `Happy Dog`, `Dark Dog`, `Black Cat`, `White Rabbit`,
`Pink Rabbit` — enumerate ได้หมด ไม่ต้องสุ่ม

### Preservation Checking

**Goal**: ยืนยันว่าทุกอินพุตที่ **ไม่** เข้าเงื่อนไขบั๊ก ให้ผลเท่ากับก่อนแก้

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT spawnFollower_original(X) = spawnFollower_fixed(X)
END FOR
```

**Testing Approach**: ตำราจะแนะนำ property-based testing เพราะสุ่มอินพุตได้กว้างและจับ edge case ที่ unit
test มือเขียนพลาด แต่ repo นี้ไม่มี framework และโดเมนอินพุตจริง **จำกัดและ enumerate ได้ทั้งหมด**
(pet Model ทุกตัวในทุก egg folder) จึงใช้ **exhaustive manual enumeration** แทนการสุ่ม ซึ่งให้การรับประกัน
ที่แรงกว่าในกรณีนี้ วิธีบันทึก "ผลก่อนแก้" คือจับ baseline ไว้ก่อน แล้วเทียบซ้ำหลังแก้

**Test Plan**: บันทึกพฤติกรรมบนโค้ด/ข้อมูล **ที่ยังไม่แก้** ก่อน (ทิศของ White Cat, ทิศของเพ็ต egg อื่น,
ตำแหน่ง/สเกล/การ lerp, จำนวน follower ตอนมีผู้เล่นหลายคน) แล้วเทียบค่าเดียวกันหลังแก้

**Test Cases**:
1. **White Cat ไม่ regress** — บันทึกทิศ White Cat ก่อนแก้ แล้วยืนยันว่าเหมือนเดิมเป๊ะหลังแก้ (3.1)
2. **เพ็ต egg อื่นไม่ถูกแตะ** — MCP query `FollowerRoot`/`FacingAttachment`/`CFrame` ของเพ็ตใน
   Uncommon/Godly/Galactic/Divine ก่อนและหลัง ต้องไม่ต่างกันเลย และทิศที่เห็นตอนเล่นเท่าเดิม (3.2)
3. **การวางตัว follower เท่าเดิม** — เพ็ตยังอยู่ขวามือ ~2.5 studs สเกล 0.75 ตามแบบ smooth และตั้งตรง
   แม้ผู้เล่นนั่งหรือ ragdoll (3.3)
4. **Multi-owner** — สอง client ใน Studio, ต่างคนต่าง equip: เห็น follower ของกันครบ และหายถูกตัวเมื่อคนหนึ่งออก (3.4)
5. **Boost/rarity/profile ไม่เปลี่ยน** — ชื่อเพ็ตในแต่ละ egg ยังตรงกับ `EconomyBalance.PET_BOOSTS`
   ทุกคีย์ ค่า boost ที่แสดงบน HUD เท่าเดิม เพ็ตในโปรไฟล์ผู้เล่นเดิมยังใช้ได้ ไม่ถูกรีเซ็ต (3.5)
6. **Legacy fallback ยังทำงาน** — จำลอง asset ที่ไม่มี `FollowerRoot` แต่ตั้ง `FacingOffsetY = 180`
   แล้วยืนยันว่ายังหันตาม offset นั้น (3.6)
7. **Build ยังสะอาด** — `rojo build` จาก `src/` ผ่าน ไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client (3.7)

### Unit Tests

ไม่มี test runner — รายการนี้คือการตรวจระดับ instance ต่อเพ็ตหนึ่งตัวด้วย MCP query (ต่อ pet Model,
ทำซ้ำได้ ตรวจได้ทีละตัว):
- `FollowerRoot` เป็น `BasePart` ลูกตรง และ `Model.PrimaryPart == FollowerRoot`
- `FollowerRoot` มี `FacingAttachment` เป็น `Attachment` และ `CFrame` ของมันเป็นค่าที่ตั้งใจ
- ไม่มี attribute `FacingOffset*` ค้างอยู่บน asset ที่ calibrate แล้ว (กันสองมาตรฐานซ้อนกัน)
- ทิศหน้าของ geometry ตรงกับ `FacingAttachment.WorldCFrame.LookVector` (dot > 0)
- `FollowerRoot.Transparency == 1` และ part ทุกตัว `Anchored`, `CanCollide = false`
- Edge case: pet Model ที่ไม่มี `BasePart` เลย ต้องได้ warn แล้วไม่ crash (เส้นทางเดิมใน `spawnPet`)

### Property-Based Tests

ไม่มี PBT framework ในโปรเจกต์นี้ และโดเมนอินพุตเล็กพอที่จะเดินให้ครบ จึงแทนการสุ่มด้วย **exhaustive
enumeration** ตรง ๆ:
- **Property 1 (fix)**: เดินครบทั้ง 6 counterexample ของ Common Egg — ไม่สุ่ม เดินให้หมด
- **Property 2 (preservation)**: เดินครบ pet Model ทุกตัวในทุก egg folder เทียบ instance data
  ก่อน/หลัง — ตัวใดไม่ได้อยู่ในชุดที่แก้ ต้องไม่ต่างกันเลยแม้แต่ field เดียว
- **มุมมองผู้เล่น**: ต่อเพ็ตที่แก้ ตรวจทิศในหลายสถานะ (เดินหน้า, ถอยหลัง, หมุนตัวเร็ว, กระโดด, นั่ง,
  หลัง re-equip, หลัง respawn, หลังเข้าเกมรอบใหม่) — ทิศต้องถูกทุกสถานะ ไม่ใช่แค่ตอน spawn

### Integration Tests

- **Full loop**: ซื้อ Common Egg → roll → equip → เดินรอบฟาร์ม → ยืนยันเพ็ตหันหน้าออก และ boost
  ยังทำงานเหมือนเดิม
- **สลับเพ็ต**: equip ครบ 7 ตัวติดกันในเซสชันเดียว ยืนยันไม่มีตัวไหนกลับด้าน และ despawn/spawn สะอาด
  ไม่มี follower ค้าง
- **Persistence (ห้ามข้าม, ห้ามเชื่อคำว่าเสร็จ)**: หลัง BAKE → Ctrl+S → **ปิด place แล้วเปิดใหม่** →
  MCP query ทั้ง 7 ตัวอีกครั้งว่า `FollowerRoot`/`PrimaryPart`/`FacingAttachment` ยังอยู่ครบ → Play
  ยืนยันทิศด้วยตาอีกรอบ (2.2)
- **Multi-client**: Studio 2 players ตรวจ follower ของทั้งสองฝ่ายพร้อมกัน และตอนคนหนึ่งออกจากเกม
- **Visual/level check**: ยืนยันเพ็ตไม่จมพื้น ไม่ลอย ไม่เอียง ในทุกจุดที่ทดสอบ และเงา/collision ยังปิดอยู่
- **Cleanup**: หลังผ่านทั้งหมด รัน `ACTION = "CLEANUP"` แล้วยืนยันว่า `Workspace.PetOrientationCalibration`
  หายไปโดย pet asset ไม่ถูกแตะ แล้ว Ctrl+S อีกครั้ง
