# Snapshot ก่อนรัน 3.2 (reference สำหรับ diff หลัง BAKE + หลังปิด/เปิด place)

เก็บเมื่อ: ก่อน `ACTION = "SETUP"` ของ task 3.2 — instance data **ยังไม่ถูกแก้**
(task 3.1 แก้แค่ `tools/CalibratePetOrientation.lua` ซึ่งเป็นไฟล์ Lua ไม่ใช่ instance)
Studio: Edit mode ยืนยันแล้ว (`state: edit`), place `FarmingRobloxSimulator` (105263904115612),
clientId `9eba4ebc-1c34-4693-9b80-ccbbcaa1ac88`, one window
`Workspace.PetOrientationCalibration` = **ไม่มี** (สะอาดพร้อม SETUP)

## ทำไมต้องมีไฟล์นี้ (แทนที่จะใช้ checksum จาก baseline-task2.md §A.1 ตรง ๆ)

checksum ใน §A.1 คำนวณด้วย FNV-1a เหมือนกัน แต่ **encoding ของ entry string ไม่ตรงกับที่ผมคำนวณรอบนี้**
หลักฐาน: ค่าที่ได้รอบนี้ต่างจาก §A.1 **ทั้ง 22 ตัว** รวมตัวที่พิสูจน์ได้ว่าไม่มีใครแตะ (Godly/Galactic/Divine)
ถ้า geometry เปลี่ยนจริงต้องต่างเฉพาะบางตัว ไม่ใช่ทุกตัว → สรุปว่าเป็นเรื่อง format ไม่ใช่เรื่องข้อมูล

สิ่งที่ยืนยันว่าข้อมูลยังตรง baseline คือ **field เชิงโครงสร้าง** ซึ่งตรงกับ §A.0 / §A.1 ทุกช่อง:
`baseParts` ต่อตัวตรงกับคอลัมน์ใน §A.1 ครบ 22 แถว, `PrimaryPart == FollowerRoot` ครบ,
`attrs = 0` ครบ (ไม่มี `FacingOffset*` ค้างที่ใด), `FacingAttachment.CFrame` เท่ากันทั้ง 22 ตัว
และตรงกับค่าใน §A.0 ทุก component

**วิธีใช้**: หลัง BAKE และหลังปิด/เปิด place ให้รัน **สคริปต์ตัวเดียวกันนี้ซ้ำ** แล้ว diff กับตารางล่าง
16 ตัวที่ไม่ใช่เป้าหมาย (รวม `White Cat`) ต้องได้ `sum` เท่าเดิมเป๊ะ

> หมายเหตุ: `baseline-task2.md` §A.1 เขียนสรุปว่า "23 แถว" แต่ตารางจริงมี **22 แถว**
> (Common 7 + Uncommon 2 + Godly 4 + Galactic 6 + Divine 3 = 22) ซึ่งตรงกับที่ query ได้รอบนี้
> เป็น label ผิดในไฟล์ baseline ไม่ใช่ pet Model หาย

## นิยาม checksum (รอบนี้)

```
สำหรับ BasePart ทุกตัวใน Model ที่ไม่ใช่ FollowerRoot:
  rel   = FollowerRoot.CFrame:Inverse() * part.CFrame
  entry = "{Name}|{ClassName}|{rel.Position 4dp}|{deg(rel:ToOrientation()) 4dp}|{part.Size 4dp}"
sort(entries) → concat(";") → FNV-1a 32-bit → "%08X"
```

## ตาราง (22 pet Model / 5 egg folder)

ทุกแถวมี `PrimaryPart == FollowerRoot` = true, attributes = 0 และ
`FacingAttachment.CFrame` = `[0,0,0, -1,0,-0, 0,1,0, 0,0,-1]` (look = root-local **+Z**) เหมือนกันหมด

| Egg | Pet | baseParts | geometry parts | **sum (pre-3.2)** | เป้าหมาย 3.2? |
|---|---|---|---|---|---|
| Common Egg | Black Cat | 2 | 1 | `F37090E4` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | Dark Dog | 2 | 1 | `AC8FBDA5` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | Dog | 2 | 1 | `1533DA63` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | Happy Dog | 2 | 1 | `6F2AE2F2` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | Pink Rabbit | 2 | 1 | `DAE3937D` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | White Rabbit | 2 | 1 | `14F3AC0E` | **ใช่ — ต้องเปลี่ยน** |
| Common Egg | **White Cat** | 4 | 3 | `DEA1FD76` | **ไม่ — ห้ามเปลี่ยน (3.1)** |
| Uncommon Egg | MewWat | 14 | 13 | `69AF1C25` | ไม่ (3.2) |
| Uncommon Egg | Snow Cat | 14 | 13 | `64D14C72` | ไม่ (3.2) |
| Godly Egg | Bluehoo | 43 | 42 | `31D1055C` | ไม่ (3.2) |
| Godly Egg | BoBo | 20 | 19 | `9EF9F55B` | ไม่ (3.2) |
| Godly Egg | Fireclouds | 36 | 35 | `FE6C09D8` | ไม่ (3.2) |
| Godly Egg | Thorney | 26 | 25 | `0E18CE55` | ไม่ (3.2) |
| Galactic Egg | Blackbear | 16 | 15 | `ADA1B018` | ไม่ (3.2) |
| Galactic Egg | Bluewing | 16 | 15 | `9FF1A0D3` | ไม่ (3.2) |
| Galactic Egg | Brownbear | 16 | 15 | `044EB02F` | ไม่ (3.2) |
| Galactic Egg | GoldPig | 11 | 10 | `E3757DD8` | ไม่ (3.2) |
| Galactic Egg | PinkPig | 11 | 10 | `644225B3` | ไม่ (3.2) |
| Galactic Egg | Whitebear | 16 | 15 | `0E7DBA7C` | ไม่ (3.2) |
| Divine Egg | Moon | 5 | 4 | `5E8B85B8` | ไม่ (3.2) |
| Divine Egg | Moon Flare | 13 | 12 | `8AD42208` | ไม่ (3.2) |
| Divine Egg | Sun Flare | 13 | 12 | `F3F364E7` | ไม่ (3.2) |

## Selection ที่ยืนยันก่อนรัน SETUP (MCP `manage_selection` → count = 6)

```
game.ReplicatedStorage.Assets.Pets["Common Egg"].Dog
game.ReplicatedStorage.Assets.Pets["Common Egg"]["Happy Dog"]
game.ReplicatedStorage.Assets.Pets["Common Egg"]["Dark Dog"]
game.ReplicatedStorage.Assets.Pets["Common Egg"]["Black Cat"]
game.ReplicatedStorage.Assets.Pets["Common Egg"]["Pink Rabbit"]
game.ReplicatedStorage.Assets.Pets["Common Egg"]["White Rabbit"]
```

`White Cat` **ไม่อยู่ใน selection** ✔ และไม่มีเพ็ตจาก egg อื่นติดมา ✔
