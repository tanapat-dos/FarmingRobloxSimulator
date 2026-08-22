# Implementation Plan

## Overview

ซ่อมทิศการหันของเพ็ต follower ใน `Common Egg` 6 ตัวที่หันกลับด้าน ~180° โดยใช้ `White Cat` เป็น known-good
baseline งานหลักอยู่ที่ **instance data ใน place** (`ReplicatedStorage.Assets.Pets["Common Egg"]`) ไม่ใช่ Lua —
`PetClient.client.lua` อ่านทิศจาก `FollowerRoot` + `FacingAttachment` ตอน spawn ส่วนที่แก้ในไฟล์คือ
`tools/CalibratePetOrientation.lua` ที่ข้อความชี้ทางขัดกับ geometry จนทำให้ bake กลับด้านซ้ำได้

ลำดับงาน: เก็บหลักฐานบั๊กก่อน → บันทึก preservation baseline → แก้ → ตรวจซ้ำด้วยชุดเดิมทั้งสองชุด

> **หมายเหตุสำคัญเรื่องการตรวจสอบ:** repo นี้ **ไม่มี automated test framework** (ไม่มี TestEZ / ไม่มี PBT library)
> "Property" ทั้งสองข้อจึงเป็น **checklist ที่คนรันแบบ exhaustive enumeration** ไม่ใช่ test case ที่รันเอง
> เครื่องมือที่ใช้แทน test runner: `rojo build` (ยืนยัน source), `get_diagnostics`, MCP instance query
> (ยืนยัน instance data + persistence) และ Studio play-test (ยืนยันสิ่งที่ตาเห็น)
> โดเมนอินพุตจำกัด (pet Model ทุกตัวในทุก egg folder) จึง **เดินให้ครบทุกตัว ไม่สุ่ม**

## Task Dependency Graph

```
1. Bug condition exploration (ต้องล้มบนข้อมูลที่ยังไม่แก้)
        │
        ▼
2. Preservation baseline (ต้องผ่านบนข้อมูลที่ยังไม่แก้)
        │
        ▼
3. Fix ─┬─ 3.1 แก้ tools/CalibratePetOrientation.lua (guard + ข้อความ)
        │        │
        │        ▼
        ├─ 3.2 Re-calibrate instance data 6 ตัว (SCOPE = "SELECTED") ← ต้องรอ 3.1
        │        │
        ├─ 3.3 ตรวจ diff + commit PetClient.client.lua (ขนานกับ 3.2 ได้)
        │        │
        │        ▼
        ├─ 3.4 รันชุดตรวจจาก task 1 ซ้ำ → ต้องผ่าน  ← ต้องรอ 3.2 และ 3.3
        │        │
        │        ▼
        └─ 3.5 รันชุดตรวจจาก task 2 ซ้ำ → ต้องผ่าน  ← ต้องรอ 3.2 และ 3.3
                 │
                 ▼
4. Checkpoint + CLEANUP (ต้องรอ 3.4 และ 3.5 ผ่านครบ)
```

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["1"],
      "description": "เก็บ counterexample บนข้อมูลที่ยังไม่แก้ (ต้องล้ม)"
    },
    {
      "wave": 2,
      "tasks": ["2"],
      "description": "บันทึก preservation baseline บนข้อมูลที่ยังไม่แก้ (ต้องผ่าน)"
    },
    {
      "wave": 3,
      "tasks": ["3.1"],
      "description": "แก้ tool: ข้อความชี้ทาง + guard ตอน bake + รายงาน tier"
    },
    {
      "wave": 4,
      "tasks": ["3.2", "3.3"],
      "description": "Re-calibrate instance data 6 ตัว และ commit PetClient โดยไม่แก้ตรรกะ orientation"
    },
    {
      "wave": 5,
      "tasks": ["3.4", "3.5"],
      "description": "รันชุดตรวจเดิมจาก task 1 และ task 2 ซ้ำ — ทั้งคู่ต้องผ่าน"
    },
    {
      "wave": 6,
      "tasks": ["4"],
      "description": "Checkpoint: integration, persistence, CLEANUP"
    }
  ]
}
```

## Tasks

- [x] 1. บันทึกหลักฐานบั๊ก (bug condition exploration) ก่อนแก้อะไรทั้งสิ้น
  - **Property 1: Bug Condition** - เพ็ต Common Egg ที่หันกลับด้านต้องหันหน้าออก
  - **CRITICAL**: ขั้นนี้ต้อง **ล้ม** บนข้อมูลที่ยังไม่แก้ — การล้มคือการยืนยันว่าบั๊กมีจริง
  - **DO NOT** แก้ instance data หรือแก้ tool ใด ๆ ในขั้นนี้
  - **GOAL**: เก็บ counterexample เพื่อ **ยืนยันหรือหักล้าง** Hypothesized Root Cause (1 = bake กลับด้าน, 2 = ยังเป็น gen1, 3 = `FacingOffset*` ถูก strip) ถ้าหักล้างได้ทั้งหมด ต้องกลับไปตั้งสมมติฐานใหม่ก่อนแก้
  - **Scoped enumeration**: โดเมนที่เดินคือ 6 counterexample ที่ระบุไว้ในดีไซน์ — `Dog`, `Happy Dog`, `Dark Dog`, `Black Cat`, `White Rabbit`, `Pink Rabbit` เทียบกับ `White Cat` (known-good baseline) เดินให้ครบทั้ง 7 ตัว ไม่สุ่ม
  - 1) **Instance tier audit** — MCP query แต่ละตัวใน `ReplicatedStorage.Assets.Pets["Common Egg"]`: มี `FollowerRoot` (BasePart ลูกตรง) ไหม, `Model.PrimaryPart == FollowerRoot` ไหม, มี `FacingAttachment` ไหม + `CFrame` เท่าไร, attribute `FacingOffsetX/Y/Z` / `FacingOffsetDegrees` เหลืออยู่ไหม — บันทึกเป็นตาราง 7 แถว
  - 2) **Geometry-vs-attachment** — เทียบทิศหน้าของ geometry กับ `FacingAttachment.WorldCFrame.LookVector` ต่อตัว ถ้า dot < 0 = bake กลับด้าน → ยืนยัน Hypothesis 1; ถ้า 6 ตัวไม่มี attachment เลย → ยืนยัน Hypothesis 2
  - 3) **Play-test baseline** — Edit mode → Ctrl+S → Play → equip `Dog` เดินไปข้างหน้า สังเกตว่าก้นออก แล้วเทียบ `White Cat` ในมุมกล้องเดียวกัน
  - 4) **Output warn audit** — ดู F9/Output ตอน equip ทั้ง 7 ตัว ว่ามี `[PetClient] ... missing FacingAttachment` หรือ `PrimaryPart was not FollowerRoot` โผล่ตัวไหน (ถ้าเงียบทั้ง 7 = Hypothesis 1)
  - **EXPECTED OUTCOME**: การตรวจ **ล้มบน 6 ตัว** (หันกลับด้าน ~180°) และ **ผ่านบน White Cat** — ตรงกับ `isBugCondition(X) = observedFacing(X) ≠ observedFacing(WhiteCat)`
  - บันทึก counterexample ที่ได้ลงไว้ (เช่น "Dog: มี FollowerRoot, ไม่มี FacingAttachment → correction = identity → หน้า = root −Z → กลับด้าน") พร้อมสรุปว่า hypothesis ข้อไหนเป็นตัวจริง
  - ถือว่า task เสร็จเมื่อ: ตาราง audit ครบ 7 ตัว + สรุป root cause จริง + counterexample ถูกบันทึก
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. บันทึก preservation baseline บนข้อมูลที่ยังไม่แก้ (ก่อนลงมือแก้)
  - **Property 2: Preservation** - ทุกอินพุตที่ไม่ใช่บั๊กต้องเหมือนเดิม
  - **IMPORTANT**: ทำตาม observation-first — สังเกตพฤติกรรมจริงบนโค้ด/ข้อมูล **ที่ยังไม่แก้** แล้วบันทึกไว้เป็นค่าอ้างอิง ห้ามเดาว่า "ควรจะเป็น" อะไร
  - **Exhaustive enumeration แทน PBT**: ไม่มี PBT framework และโดเมนเดินได้ครบ จึง enumerate pet Model ทุกตัวในทุก egg folder แทนการสุ่ม (ให้การรับประกันแรงกว่าในกรณีนี้)
  - บันทึกทิศที่เห็นของ `Common Egg.White Cat` (known-good witness) พร้อมภาพ/มุมกล้องอ้างอิง (3.1)
  - MCP query + บันทึก `FollowerRoot` / `PrimaryPart` / `FacingAttachment.CFrame` / attribute `FacingOffset*` ของเพ็ต **ทุกตัวในทุก egg folder** (Uncommon, Rare, Godly, Galactic, Divine ฯลฯ) และบันทึกทิศที่เห็นตอนเล่นของอย่างน้อย 1 ตัวจาก 2 egg (3.2)
  - บันทึกการวางตัว follower: offset `Vector3.new(2.5, 0, 0)` ทางขวา, `ScaleTo(0.75)`, `Lerp(target, 0.15)` แบบ smooth, ตั้งตรงระดับพื้นแม้ผู้เล่นนั่ง/ragdoll (3.3)
  - บันทึกพฤติกรรม multi-owner: Studio 2 players ต่างคนต่าง equip เห็น follower ของกันครบตาม `ownerUserId` และหายถูกตัวตอนคนหนึ่งออก (3.4)
  - บันทึกค่าอ้างอิงของ boost/ชื่อเพ็ต/rarity: ชื่อเพ็ตในทุก egg folder ตรงกับคีย์ใน `EconomyBalance.PET_BOOSTS` และค่า boost ที่โผล่บน HUD (3.5)
  - บันทึกว่า legacy fallback ยังทำงาน: asset ที่ไม่มี `FollowerRoot` + ตั้ง `FacingOffsetY = 180` ยังหันตาม offset (3.6)
  - รัน `rojo build` จาก `src/` ครั้งหนึ่งเป็น baseline ว่าผ่านสะอาดอยู่แล้ว (3.7)
  - **EXPECTED OUTCOME**: ทุกข้อ **ผ่าน** บนข้อมูลที่ยังไม่แก้ — นี่คือ baseline ที่หลังแก้ต้องเท่ากันเป๊ะ (`F(X) = F'(X)`)
  - ถือว่า task เสร็จเมื่อ baseline ทุกข้อถูกบันทึกและยืนยันว่าผ่านก่อนแก้
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. ซ่อมทิศการหันของเพ็ต Common Egg 6 ตัว

  - [x] 3.1 แก้ `tools/CalibratePetOrientation.lua` ให้ข้อความชี้ทางตรงกับ geometry และเพิ่ม guard
    - แก้ข้อความใน `setup()` จาก `"face the red -Z marker"` ให้บอกตรงกันว่าให้หมุน **หน้าของสัตว์ไปทางลูกบอลเหลือง (`FacingTip`)** ปลายแท่งแดง (local +Z) — ให้ header comment, ข้อความ print และตำแหน่ง guide เล่าเรื่องเดียวกัน
    - เพิ่ม guard ใน `bakeStation`: เทียบทิศหน้าของ `Visuals` กับ `stationFacing.WorldCFrame.LookVector` ถ้า dot < 0 → `error` พร้อมบอกว่าให้หมุน `Visuals` 180° **ไม่ใช่** หมุน `FollowerRoot`
    - ให้ `SETUP` print tier ของแต่ละ station (gen2 / gen1 / legacy + ค่า `FacingOffset*` ที่เหลือ) เพื่อให้แยก hypothesis ได้จาก output
    - ตรวจด้วย `get_diagnostics` แล้ว commit ไฟล์นี้ (ยัง untracked)
    - _Bug_Condition: isBugCondition(X) = observedFacing(X) ≠ observedFacing(WhiteCat)_
    - _Expected_Behavior: Property 1 — facesForward, angle ≤ 10°, isLevel, usesExistingCalibrationContract_
    - _Preservation: Preservation Requirements — ห้ามแตะ White Cat / egg อื่น / PetService / EconomyBalance_
    - _Requirements: 2.4, 2.5, 3.7_

  - [x] 3.2 Re-calibrate instance data ของเพ็ต 6 ตัวใน `ReplicatedStorage.Assets.Pets["Common Egg"]`
    - Edit mode เท่านั้น — เลือกเฉพาะ `Dog`, `Happy Dog`, `Dark Dog`, `Black Cat`, `White Rabbit`, `Pink Rabbit` และตั้ง `SCOPE = "SELECTED"` — **ห้ามใช้ `SCOPE = "ALL"`** เพราะจะลาก White Cat และเพ็ต egg อื่นเข้ามาด้วย (เสี่ยง regress 3.1/3.2 ตรง ๆ)
    - `ACTION = "SETUP"` → หมุน `Visuals` ของแต่ละ station ให้หน้าชี้ไปทางลูกบอลเหลืองและตั้งตรง — **ห้ามหมุน `FollowerRoot`**
    - `ACTION = "BAKE"` + `CONFIRM_BAKE = true` → อ่าน self-check ให้ครบทุกบรรทัด รวม guard ใหม่จาก 3.1
    - ผลลัพธ์: ทั้ง 7 ตัวเป็น gen2 เหมือนกัน (`FollowerRoot` เป็น `PrimaryPart` + `FacingAttachment`) และชื่อเพ็ตทุกตัวคงเดิมเพื่อไม่ให้ `PET_BOOSTS` lookup พลาด
    - Ctrl+S แล้ว **ปิด place เปิดใหม่** → MCP query ทั้ง 7 ตัวอีกครั้งเพื่อยืนยัน persistence ด้วยตัวเอง (ห้ามรับคำว่า "เสร็จแล้ว" แบบเชื่อใจ)
    - _Bug_Condition: isBugCondition(X) เป็นจริงกับ 6 ตัวนี้เท่านั้น_
    - _Expected_Behavior: Property 1 — persistsAfterSaveAndReopen(X)_
    - _Preservation: White Cat และเพ็ต egg อื่นต้องไม่ถูกแตะแม้แต่ field เดียว_
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.3 ตรวจ diff และ commit `src/client/panels/PetClient.client.lua` โดยไม่แก้ตรรกะ orientation
    - **ห้ามเพิ่มกลไก orientation ชุดที่สอง** — สามชั้นเดิม (`FacingAttachment` → `FollowerRoot` identity → legacy `FacingOffset*`) ถูกต้องแล้ว
    - ตรวจ diff ของไฟล์ที่ยัง modified ไม่ commit แล้ว commit ให้จบ เพื่อไม่ให้ Studio กับ `src/` หลุดกัน
    - ยืนยันว่า warn เดิม (`PrimaryPart was not FollowerRoot`, `missing FacingAttachment`, `has no BasePart`, `Missing pet model`) ยังอยู่ครบ — ถ้าจะเพิ่ม เพิ่มได้แค่ warn ที่ช่วยตรวจ 2.5
    - ยืนยันว่าไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client และไม่แตะ `PetService` / `DataService` / `EconomyBalance`
    - รัน `get_diagnostics` + `rojo build` จาก `src/` ครั้งเดียวหลังแก้ครบทั้ง batch
    - _Bug_Condition: isBugCondition(X) — ไฟล์นี้ไม่ใช่จุดที่บั๊กอยู่_
    - _Expected_Behavior: Property 1 — usesExistingCalibrationContract(X), warn เมื่อข้อมูลไม่ครบ_
    - _Preservation: 3.6 legacy fallback, 3.7 build สะอาด + ไม่ย้ายตรรกะมา client_
    - _Requirements: 2.4, 2.5, 3.6, 3.7_

  - [x] 3.4 ยืนยันว่าการตรวจ bug condition จากขั้นที่ 1 ผ่านแล้ว
    - **Property 1: Expected Behavior** - เพ็ต Common Egg ที่หันกลับด้านต้องหันหน้าออก
    - **IMPORTANT**: รัน **ชุดตรวจเดิมจาก task 1** ซ้ำ — ห้ามเขียนชุดตรวจใหม่ ชุดเดิมคือสิ่งที่ encode expected behavior ไว้
    - เดินให้ครบทั้ง 6 ตัว: `facesForward` (หน้าออก ไม่ใช่ก้นออก), `angleTo(observedFacing(WhiteCat)) ≤ 10°`, `isLevel` (ไม่เอียง ไม่พลิก)
    - ตรวจหลายสถานะต่อเพ็ตแต่ละตัว: เดินหน้า, ถอยหลัง, หมุนตัวเร็ว, กระโดด, นั่ง, หลัง re-equip, หลัง respawn, หลังเข้าเกมรอบใหม่
    - ตรวจ persistence อีกครั้งหลัง Ctrl+S → ปิด/เปิด place → Play (2.2)
    - ตรวจ Output ว่าไม่มี warn ค้างสำหรับ 7 ตัวนี้ และยัง warn เมื่อข้อมูลไม่ครบ (2.5)
    - **EXPECTED OUTCOME**: ผ่านทั้ง 6 ตัว (ยืนยันว่าบั๊กหายจริง)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 3.5 ยืนยันว่า preservation baseline จากขั้นที่ 2 ยังผ่านครบ
    - **Property 2: Preservation** - ทุกอินพุตที่ไม่ใช่บั๊กต้องเหมือนเดิม
    - **IMPORTANT**: รัน **ชุดตรวจเดิมจาก task 2** ซ้ำ แล้วเทียบกับค่าที่บันทึกไว้ก่อนแก้ — ห้ามเขียนชุดใหม่
    - White Cat ทิศเหมือนเดิมเป๊ะ (3.1)
    - เพ็ตทุกตัวในทุก egg folder อื่น: `FollowerRoot` / `PrimaryPart` / `FacingAttachment.CFrame` / `FacingOffset*` **ไม่ต่างกันเลยแม้แต่ field เดียว** และทิศที่เห็นตอนเล่นเท่าเดิม (3.2)
    - offset 2.5 ทางขวา, สเกล 0.75, lerp แบบ smooth, ตั้งตรงระดับพื้นแม้นั่ง/ragdoll (3.3)
    - Multi-owner: 2 players เห็น follower ของกันครบ และหายถูกตัวเมื่อคนหนึ่งออก (3.4)
    - ชื่อเพ็ต/boost/rarity/gacha odds/profile data ไม่เปลี่ยน; ค่า boost บน HUD เท่าเดิม; เพ็ตในโปรไฟล์เดิมยังใช้ได้ ไม่ถูกรีเซ็ต (3.5)
    - Legacy fallback `FacingOffsetY = 180` ยังทำงาน (3.6)
    - `rojo build` จาก `src/` ผ่านสะอาด และไม่มีตรรกะเกมเพลย์ย้ายมาฝั่ง client (3.7)
    - **EXPECTED OUTCOME**: ผ่านทั้งหมด เท่ากับ baseline ก่อนแก้ (ไม่มี regression)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 4. Checkpoint - ยืนยันทุกการตรวจผ่าน แล้วเก็บงานให้เรียบร้อย
  - Integration: ซื้อ Common Egg → roll → equip → เดินรอบฟาร์ม → เพ็ตหันหน้าออกและ boost ทำงานเหมือนเดิม
  - สลับ equip ครบทั้ง 7 ตัวในเซสชันเดียว: ไม่มีตัวไหนกลับด้าน, ไม่มี follower ค้าง, เพ็ตไม่จมพื้น ไม่ลอย ไม่เอียง, เงา/collision ยังปิดอยู่
  - รัน `ACTION = "CLEANUP"` **หลัง** ยืนยันด้วยการเล่นจริงแล้วเท่านั้น → ยืนยันว่า `Workspace.PetOrientationCalibration` หายไปโดย pet asset ไม่ถูกแตะ → Ctrl+S อีกครั้ง → MCP query ยืนยันครั้งสุดท้าย
  - ยืนยันว่า Property 1 (task 3.4) และ Property 2 (task 3.5) ผ่านครบ ถ้ามีข้อไหนไม่ผ่านหรือมีข้อสงสัย ให้หยุดและถามผู้ใช้ก่อน

## Notes

- **ไม่มี test runner ในโปรเจกต์นี้** — ห้ามสร้าง test framework ใหม่เพื่องานนี้ Property 1/2 ตรวจด้วย
  `rojo build` + `get_diagnostics` + MCP instance query + Studio play-test ตามที่ดีไซน์กำหนด
- **task 1 ต้องล้ม** บนข้อมูลที่ยังไม่แก้ และ **task 2 ต้องผ่าน** บนข้อมูลที่ยังไม่แก้ ถ้าผลกลับกัน แปลว่าเข้าใจ
  บั๊กผิด ให้หยุดและตั้งสมมติฐานใหม่ก่อนแก้อะไร
- **`SCOPE = "SELECTED"` เท่านั้น** ใน `CalibratePetOrientation` — `SCOPE = "ALL"` จะลาก White Cat และเพ็ต
  egg อื่นเข้ามา ซึ่ง regress 3.1/3.2 โดยตรง
- **Edit mode สำหรับทุกการเขียนลง Studio** และ Wire → Ctrl+S → Play เสมอ; หนึ่ง Studio window / หนึ่ง place
- **ยืนยัน persistence เอง** — หลัง BAKE ต้อง Ctrl+S แล้วปิด/เปิด place แล้ว query ซ้ำ ห้ามรับคำว่า "เสร็จแล้ว"
  แบบเชื่อใจ (บทเรียนเดียวกับ `SeedData` ที่ instance data เป็น source of truth ไม่ใช่ Lua)
- **ห้ามแตะ**: `PetService`, `DataService`, `EconomyBalance` (`PET_BOOSTS`, `PET_BOOST_RANGES`,
  `PET_GROWTH_REDUCTION`), pet Model ของ egg อื่น, Workspace source models
- **ห้ามย้ายตรรกะเกมเพลย์มาฝั่ง client** — งานนี้เป็น presentation fix ฝั่ง client visual เท่านั้น และไม่เพิ่ม
  กลไก orientation ชุดที่สอง (2.4)
- `ACTION = "CLEANUP"` ทำได้เฉพาะ **หลัง** ยืนยันด้วยการเล่นจริงว่าทั้ง 7 ตัวถูกต้องแล้ว
