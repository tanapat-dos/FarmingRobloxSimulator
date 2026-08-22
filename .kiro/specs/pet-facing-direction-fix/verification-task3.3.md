# Task 3.3 — Review & Commit `src/client/panels/PetClient.client.lua`

ขอบเขต: **review-and-commit เท่านั้น** — ไม่แก้ตรรกะ orientation แม้แต่บรรทัดเดียว
(task 1 ยืนยันแล้วว่าบั๊กอยู่ใน baked geometry ไม่ใช่ในไฟล์นี้; task 3.2 แก้ instance data ไปแล้ว)

Commit: `c51bd5e` — *Adopt FollowerRoot/FacingAttachment contract in pet follower client*
staged 1 ไฟล์ (`56 insertions / 43 deletions`) ไม่มี amend ไม่มี force

---

## 1) สิ่งที่ diff ที่ค้างอยู่ทำ (อ่านทีละบรรทัด)

diff คือการย้ายไฟล์นี้จาก **สัญญาเก่า (attribute-only)** มาเป็น **สัญญา gen2 ที่ 3.2 ใช้จริง**:

| # | การเปลี่ยน | ประเมิน |
|---|---|---|
| 1 | `getFacingOffset` → แยกเป็น `getFollowerRoot` / `getFacingAttachment` / `getLegacyFacingOffset` | ✔ คือกลไก **ชุดเดียว** ที่แทนของเก่า ไม่ใช่ชุดที่สองซ้อนเข้ามา |
| 2 | `facingCorrection` 3 ชั้น: `FacingAttachment:Inverse()` → `CFrame.new()` → `getLegacyFacingOffset` | ✔ ลำดับตรงตาม 2.4 / 3.6 |
| 3 | ตัด early-return `if x==0 and y==0 and z==0 then return CFrame.new()` | ✔ no-op — `CFrame.Angles(0,0,0) == CFrame.new()` พฤติกรรมเท่าเดิม |
| 4 | บังคับ `model.PrimaryPart = followerRoot` บน clone (fallback เดิมยังอยู่) | ✔ ตรงสัญญา gen2 |
| 5 | เพิ่ม `part.CanTouch = false` / `part.CanQuery = false` บน clone | ✔ presentation-only ตรงกับ baseline §B.1 |
| 6 | เพิ่ม warn 3 ตัว + guard `has no BasePart` (destroy แล้ว return ไม่ crash) | ✔ ตอบ 2.5 |
| 7 | rename `facingOffset` → `facingCorrection` (4 จุดใช้งาน) + ย่อ comment block | ✔ cosmetic |

**ไม่พบ**: กลไก orientation ชุดที่สอง, การเดาทิศจาก mesh bounds, ตรรกะเกมเพลย์ย้ายมา client,
การลบ warn เดิม → ไม่ต้องแก้อะไรเพิ่ม รับ diff ตามที่เป็นแล้ว commit

**ไม่เพิ่ม warn ใหม่** (แม้ task เปิดช่องให้): เคสบั๊กจริงคือ geometry หันสวน `FacingAttachment` ซึ่ง
evidence-task1 §2 พิสูจน์แล้วว่า **อ่านจาก instance data ฝั่ง runtime ไม่ได้** (6 ตัวมี visual part เดียวที่
`relPos ≈ (0,0,0)`) จะ warn ได้ต้องเดาจาก mesh bounds ซึ่งเป็นสิ่งที่ header comment ห้ามไว้ตรง ๆ
guard ที่จับเคสนี้ถูกวางไว้ที่ **bake time** ใน `tools/CalibratePetOrientation.lua` (task 3.1) แล้ว — ถูกที่กว่า

## 2) 3-tier orientation contract — ยังเดิมและลำดับเดิม

```lua
local facingCorrection = if sourceFacingAttachment
    then sourceFacingAttachment.CFrame:Inverse()   -- gen2
    elseif sourceFollowerRoot then CFrame.new()    -- gen1 identity
    else getLegacyFacingOffset(src)                -- legacy FacingOffset*
```

`getLegacyFacingOffset` อ่าน `FacingOffsetX/Y/Z` และ fallback `FacingOffsetDegrees` → `FacingOffsetY = 180`
และ `FacingOffsetDegrees = 180` ยังพลิก 180° ทั้งคู่ ตรงกับ baseline §E เคส A / C (3.6) ✔

## 3) warn ครบทั้งสี่ (2.5)

| warn | บรรทัดในไฟล์ที่ commit |
|---|---|
| `Calibrated pet PrimaryPart was not FollowerRoot; repairing clone:` | ✔ |
| `Calibrated pet is missing FacingAttachment:` | ✔ |
| `Pet model has no BasePart:` | ✔ (+ `model:Destroy()` แล้ว return) |
| `Missing pet model:` | ✔ (และ `Missing egg folder:` ยังอยู่) |

## 4) ค่าคงที่การวางตัว follower — เท่ากับ baseline §B เป๊ะ (3.3)

`FOLLOW_OFFSET = Vector3.new(2.5, 0, 0)` · `FOLLOW_UP = Vector3.new(0, 1, 0)` ·
`model:ScaleTo(0.75)` · `pivot:Lerp(target, 0.15)` บน `RunService.Heartbeat` ·
`computeFollowTarget` ยังสร้าง level frame ด้วย `CFrame.lookAt(position, position + LookVector, FOLLOW_UP)`
→ ไม่มี field ใดถูกแตะ

## 5) ไม่มีตรรกะเกมเพลย์ฝั่ง client (3.7)

ไฟล์นี้ทำแค่: resolve PetShop UI / toggle blur+HUD / spawn-despawn follower ตาม `ownerUserId` ที่
`PetFollowUpdate` ส่งมา / เปิด UI ตอน `PetRollResult.success` — **ไม่มีการตัดสินเงิน ราคา inventory หรือ ownership**
และไม่แตะ `PetService` / `DataService` / `EconomyBalance` (ยืนยันจาก `git show --stat`: 1 ไฟล์)

## 6) Build / diagnostics (3.7)

```
get_diagnostics src/client/panels/PetClient.client.lua → No diagnostics found
rojo build (repo root, default.project.json) → Built project ... EXIT=0
```
สะอาด เท่ากับ baseline §F ✔ (หมายเหตุ: project file อยู่ที่ repo root ไม่ใช่ `src/` — รัน build จาก root)

## 7) Commit hygiene

```
c51bd5e  src/client/panels/PetClient.client.lua | 99 ++++++-----  (1 file changed)
```
ไฟล์ modified ที่ไม่เกี่ยวข้อง **ไม่ถูกแตะเลย** ยัง `M` อยู่ตามเดิมครบ:
`.kiro/settings/mcp.json`, `default.project.json`, `WeatherClient.client.lua`, `WeatherSounds.lua`,
`tools/IntegrateCropFromSelection.lua`, `tools/IntegratePetsFromSelection.lua`, `tools/MigrateNewFarmSoil.lua`

## สรุป

| Requirement | ผล |
|---|---|
| 2.4 ใช้สัญญา calibration เดิม ไม่มีกลไกที่สอง | **PASS** |
| 2.5 warn เมื่อข้อมูลไม่ครบ | **PASS** (4/4 warn) |
| 3.6 legacy `FacingOffset*` fallback | **PASS** (ลำดับชั้นเดิม) |
| 3.7 build สะอาด + ไม่ย้ายตรรกะมา client | **PASS** |

`src/` กับ Studio ไม่หลุดกันสำหรับไฟล์นี้แล้ว (ตรรกะไม่เปลี่ยนจากที่ Studio ใช้อยู่ระหว่าง task 1–3.2 —
diff นี้เป็นการ commit ของที่ทดสอบมาแล้ว) การยืนยันด้วยการเล่นจริงเป็นงานของ task 3.4
