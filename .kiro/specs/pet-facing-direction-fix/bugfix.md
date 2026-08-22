# Bugfix Requirements Document

## Introduction

เพ็ตที่สวมอยู่ (equipped follower pet) ของ **Common Egg** หันกลับด้าน — "หันตูดออกมา" คือท้ายลำตัวชี้ไปทางที่ผู้เล่นเดินไป แทนที่หน้าจะชี้ไปข้างหน้า อาการเกิดกับทุกตัวใน lineup ยกเว้น **White Cat** ที่หันถูกต้อง

lineup ของ Common Egg ตาม `EconomyBalance.PET_BOOSTS["Common Egg"]` มี 7 ตัว: Dog, Happy Dog, Dark Dog, White Cat, Black Cat, White Rabbit, Pink Rabbit — เท่ากับ **1 ตัวถูก / 6 ตัวผิด**

ทิศการหันของเพ็ตไม่ได้ hardcode ไว้ใน Lua แต่มาจาก **instance data ใน Studio** (`FollowerRoot` + `FacingAttachment` บนแต่ละ pet Model ใน `ReplicatedStorage.Assets.Pets.<Egg>`) ซึ่ง `PetClient.client.lua` อ่านตอน runtime ตามสัญญา calibration ที่มีอยู่แล้ว ความจริงข้อนี้สำคัญต่อขอบเขตของบั๊ก: **แก้ Lua เพียงอย่างเดียวไม่ทำให้หายเลย** เหมือนกรณี `SeedData` ที่เป็น source of truth ของค่าพืชจริง ไม่ใช่ `EconomyBalance.lua` การซ่อมต้องเกิดกับ instance data และต้องยืนยันว่า **persist** หลังบันทึก place

ข้อเท็จจริงที่ White Cat ตัวเดียวถูก บ่งชี้ว่านี่คือข้อมูลระดับ per-model ไม่ใช่ logic กลางที่ผิด — และน่าจะเป็นผลจากการแก้บางส่วนที่ทำไว้ก่อนหน้า (มี `tools/CalibratePetOrientation.lua` ที่ยัง untracked และ validation place snapshots ค้างอยู่ใน `.sync-temp/`) จึงใช้ **White Cat เป็น known-good witness / baseline** ในการซ่อมตัวที่เหลือได้ตามที่ผู้ใช้ถาม — แนวทางนี้ยืนยันว่าใช้ได้ และเป็น baseline ที่ระบุไว้ใน 2.3

เพ็ต follower เป็น client-side visual-only จึงเป็นบั๊กด้านการนำเสนอ (asset/presentation) ไม่ใช่บั๊กด้าน security หรือ data integrity

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN ผู้เล่นสวมเพ็ต Common Egg ตัวใดก็ได้ที่ไม่ใช่ White Cat (Dog, Happy Dog, Dark Dog, Black Cat, White Rabbit, Pink Rabbit) THEN the system แสดงเพ็ตหันกลับด้าน คือท้าย/ก้นชี้ไปทางที่ผู้เล่นหันหน้า (คลาดจากทิศที่ถูกต้องราว 180°)

1.2 WHEN ผู้เล่นเดินหรือหมุนเปลี่ยนทิศ THEN the system หมุนเพ็ตตามผู้เล่นได้ลื่นไหลถูกต้อง แต่ยังคงล็อกทิศที่กลับด้านไว้เหมือนเดิม — อาการไม่หายเอง ไม่ขึ้นกับมุมกล้อง และไม่ขึ้นกับตำแหน่งบนแมป

1.3 WHEN ผู้เล่น re-equip เพ็ตตัวเดิม หรือ respawn หรือเข้าเกมรอบใหม่ THEN the system แสดงทิศกลับด้านซ้ำเดิมทุกครั้ง — เป็น defect ถาวรของตัวโมเดล ไม่ใช่อาการชั่วคราวตอน spawn

1.4 WHEN เทียบ White Cat กับเพ็ต Common Egg ตัวอื่นในเงื่อนไขทดสอบเดียวกัน THEN the system ให้ผลสองมาตรฐานภายใน egg เดียวกัน (White Cat ถูก, อีก 6 ตัวกลับด้าน)

### Expected Behavior (Correct)

2.1 WHEN ผู้เล่นสวมเพ็ต Common Egg ตัวใดก็ได้ที่ไม่ใช่ White Cat THEN the system SHALL แสดงเพ็ตหันหน้าไปทางเดียวกับที่ผู้เล่นหันหน้า (หน้าออก ไม่ใช่ก้นออก) โดยคลาดเคลื่อนได้ไม่เกิน ~±10°

2.2 WHEN ผู้เล่นเดิน หมุนตัว re-equip respawn หรือเข้าเกมรอบใหม่ THEN the system SHALL คงทิศที่ถูกต้องไว้ตลอด และทิศที่ถูกต้อง SHALL persist หลังบันทึก place แล้วเปิดใหม่ (ตรวจซ้ำเอง ไม่รับคำว่า "เสร็จแล้ว" แบบเชื่อใจ)

2.3 WHEN ตรวจความถูกต้องของทิศ THEN the system SHALL ให้ผลของเพ็ต Common Egg ทุกตัวเทียบเท่า White Cat ในเงื่อนไขทดสอบเดียวกัน — White Cat เป็น known-good baseline ของงานนี้

2.4 WHEN ซ่อมทิศการหัน THEN the system SHALL ยังใช้สัญญา calibration เดิม (`FollowerRoot` เป็น `Model.PrimaryPart` + `FacingAttachment` ที่ LookVector = หน้า, UpVector = บน) SHALL ไม่สร้างกลไก orientation ชุดที่สองขึ้นมาซ้อน

2.5 WHEN เพ็ตตัวใดยังไม่ผ่าน calibration หรือข้อมูลไม่ครบ THEN the system SHALL ส่งเสียงเตือนที่มองเห็นได้ (warn เดิมใน Output) แทนที่จะเงียบแล้วแสดงทิศผิด

### Unchanged Behavior (Regression Prevention)

3.1 WHEN ผู้เล่นสวม White Cat THEN the system SHALL CONTINUE TO แสดงทิศหันหน้าที่ถูกต้องเหมือนปัจจุบัน — ห้าม regress ตัวที่ดีอยู่แล้ว

3.2 WHEN ผู้เล่นสวมเพ็ตจาก egg อื่น (Uncommon, Rare, Godly, Galactic, Divine ฯลฯ) THEN the system SHALL CONTINUE TO แสดงทิศเท่าที่เป็นอยู่ตอนนี้ โดยไม่ถูกเปลี่ยนโดยไม่ได้ตั้งใจ

3.3 WHEN เพ็ตเดินตามผู้เล่น THEN the system SHALL CONTINUE TO วางเพ็ตให้ตั้งตรงระดับพื้น (ไม่เอียง ไม่พลิก แม้ผู้เล่นนั่งหรือ ragdoll) ที่ offset 2.5 ทางขวาของผู้เล่น สเกล 0.75 และเคลื่อนตามแบบ smooth lerp เดิม

3.4 WHEN ผู้เล่นคนอื่นในเซิร์ฟเวอร์สวมเพ็ต THEN the system SHALL CONTINUE TO spawn follower ของเจ้าของทุกคนตาม `ownerUserId` และลบทิ้งถูกตัวเมื่อผู้เล่นออก

3.5 WHEN ซ่อม instance data ของเพ็ต THEN the system SHALL CONTINUE TO ให้ค่า pet boost, ชื่อเพ็ต, rarity, gacha odds และ profile data เดิมไม่เปลี่ยน (`EconomyBalance.PET_BOOSTS`, `PET_BOOST_RANGES`, ข้อมูลผู้เล่น)

3.6 WHEN เพ็ตตัวที่ยังไม่ calibrate ถูก spawn THEN the system SHALL CONTINUE TO ใช้ legacy `FacingOffsetX/Y/Z` / `FacingOffsetDegrees` เป็น fallback ตามเดิม

3.7 WHEN มีการแก้ไขเพื่อซ่อมบั๊กนี้ THEN the system SHALL CONTINUE TO build ผ่าน `rojo build` จาก `src/` ได้สะอาด และ SHALL CONTINUE TO ไม่ย้ายตรรกะเกมเพลย์ใดๆ มาไว้ฝั่ง client

### Bug Condition C(X)

พื้นที่อินพุต `X` คือ pet Model แต่ละตัวใน `ReplicatedStorage.Assets.Pets.<Egg>` (สนใจ `Common Egg` เป็นหลัก)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type PetAssetModel
  OUTPUT: boolean

  // X ผิดเมื่อทิศ "หน้า" ที่ผ่านการ calibrate ของ X
  // ไม่ตรงกับทิศหน้าที่ผู้เล่นหัน — โดยวัดเทียบกับ White Cat ที่เป็น known-good
  RETURN observedFacing(X) ≠ observedFacing(WhiteCat)
END FUNCTION
```

witnesses ที่ใช้ยืนยัน:

| X | isBugCondition(X) | บทบาท |
|---|---|---|
| `Common Egg.White Cat` | false | known-good baseline / preservation witness |
| `Common Egg.Dog` | true | counterexample |
| `Common Egg.Happy Dog` | true | counterexample |
| `Common Egg.Dark Dog` | true | counterexample |
| `Common Egg.Black Cat` | true | counterexample |
| `Common Egg.White Rabbit` | true | counterexample |
| `Common Egg.Pink Rabbit` | true | counterexample |

### Fix Checking

```pascal
// Property: Fix Checking — ทุกเพ็ตที่ผิดต้องหันหน้าออก
FOR ALL X WHERE isBugCondition(X) DO
  result ← spawnFollower'(X)
  ASSERT facesForward(result)                       // หน้าออก ไม่ใช่ก้นออก
  ASSERT angleTo(result, observedFacing(WhiteCat)) ≤ 10°
  ASSERT isLevel(result)                            // ไม่เอียง ไม่พลิก
  ASSERT persistsAfterSaveAndReopen(X)
END FOR
```

### Preservation Checking

```pascal
// Property: Preservation Checking — ทุกอย่างที่ไม่ใช่บั๊กต้องเหมือนเดิม
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT spawnFollower(X) = spawnFollower'(X)       // F(X) = F'(X)
END FOR
```

`F` = พฤติกรรมก่อนแก้, `F'` = พฤติกรรมหลังแก้ กรณี `NOT isBugCondition(X)` ครอบคลุม White Cat และเพ็ตของ egg อื่นทุกตัว (3.1, 3.2)

### หมายเหตุเรื่องการตรวจสอบ

repo นี้ **ไม่มี automated test framework** — Fix Checking และ Preservation Checking ข้างต้นเป็น property ที่ตรวจด้วยมือ ไม่ใช่ unit test:

- `rojo build` จาก `src/` เพื่อยืนยันว่า source ยังถูกต้อง (ครอบคลุม 3.7)
- Studio play-test (Edit mode → Ctrl+S → Play) สวมเพ็ตแต่ละตัวและดูทิศจริง
- MCP instance query ตรวจ `FollowerRoot` / `PrimaryPart` / `FacingAttachment` ของแต่ละ pet Model และตรวจอีกครั้งหลังบันทึกไฟล์เพื่อยืนยัน persistence
