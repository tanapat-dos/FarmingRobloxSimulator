# Task 1 — Bug Condition Exploration Evidence (ก่อนแก้อะไรทั้งสิ้น)

สถานะข้อมูล: **ยังไม่แก้** (no instance data, no tool, no source file was modified while collecting this)
วิธีเก็บ: MCP read-only query / Luau evaluation บน `game.ReplicatedStorage.Assets.Pets["Common Egg"]`
Studio: Edit mode, place `FarmingRobloxSimulator` (105263904115612), one window

---

## 1) Instance tier audit — ครบ 7 แถว

| Pet | Model | `FollowerRoot` (BasePart ลูกตรง) | `PrimaryPart == FollowerRoot` | `FacingAttachment` | `FacingAttachment.CFrame` | `FacingOffset*` attributes | Tier |
|---|---|---|---|---|---|---|---|
| `Dog` | ✔ | ✔ (`Part`, size 1,1,1) | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `Happy Dog` | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `Dark Dog` | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `White Cat` *(baseline)* | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `Black Cat` | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `White Rabbit` | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |
| `Pink Rabbit` | ✔ | ✔ | ✔ | ✔ | orient (0, **−180°**, 0) → look **+Z**, pos (0,0,0) | none | **gen2** |

`FollowerRoot.CFrame.LookVector` = `(0, 0, −1)` (ไม่ถูกหมุน) ทั้ง 7 ตัว

**ผลชี้ขาด: ทั้ง 7 ตัวเป็น gen2 เหมือนกันเป๊ะ และ `FacingAttachment.CFrame` เท่ากันทุกตัวแบบไม่ต่างแม้แต่ bit เดียว**
→ ตัวแปรที่ทำให้ 6 ตัวผิดและ White Cat ถูก **ไม่ใช่ tier และไม่ใช่ attachment** เหลือทางเดียวคือ **geometry ที่ถูก bake ไว้**

---

## 2) Geometry-vs-attachment

`attachment look ใน root-local` = `+Z` ทั้ง 7 ตัว ต่อไปนี้คือ visual part เทียบกับ `FollowerRoot`:

| Pet | visual parts | relative yaw ของ part หลัก | part-local look | mesh id | mesh family |
|---|---|---|---|---|---|
| `Dog` | `Head` (`Part` + SpecialMesh) | **0°** | `−Z` (สวนทาง attachment) | `2913594807` | เดี่ยว (ของเก่า) |
| `Happy Dog` | `Head` (MeshPart) | **−180°** | `+Z` | `11727816926` | pack `117278…` |
| `Dark Dog` | `Head` | **−180°** | `+Z` | `11727816260` | pack `117278…` |
| `White Cat` | `Head`, `Stone`, `Inner` | `Head` **0°** (`Stone` −180°, `Inner` 176.8°) | `−Z` | `1461041563` / `1461044710` / `1461040253` | pack `1461…` |
| `Black Cat` | `Head` | **−180°** | `+Z` | `11727816559` | pack `117278…` |
| `White Rabbit` | `Head` | **−180°** | `+Z` | `11727814769` | pack `117278…` |
| `Pink Rabbit` | `Head` | **−180°** | `+Z` | `11727815843` | pack `117278…` |

หมายเหตุสำคัญ 2 ข้อ:

- **6 ตัวที่ผิดมี visual part เดียว วางที่ `relPos ≈ (0,0,0)` — ไม่มี asymmetry เชิงตำแหน่งให้อ่าน**
  ทิศหน้าของมันฝังอยู่ใน mesh เอง (`Head` เป็นชื่อที่ผิด มันคือทั้งตัว size ~2.5×3.6×2.8) จึงอ่านจาก
  instance data ตรง ๆ ไม่ได้ ต้องอาศัยตาดู
- **`White Cat` เป็นตัวเดียวที่มี asymmetry เชิงตำแหน่งอ่านได้**: `Head` (หัวแมวจริง ๆ size 1.9×0.6×1.87)
  อยู่ที่ `relPos.Z = +0.715` = **ด้านหน้าตาม attachment look (+Z)** ส่วน `Stone` (ฐาน) อยู่ที่ `Z = −0.143`
  → หัวอยู่ฝั่งหน้าของ attachment = **ตรงกับ known-good ที่รายงานมา** ✔

`relative yaw` ไม่ได้แบ่ง 1-vs-6 (มันแบ่ง 2-vs-5 ตาม **mesh family** — `Dog`/`White Cat` = 0°, pack
`117278…` 5 ตัว = −180°) เพราะแต่ละ pack authored forward axis ไม่เหมือนกัน ตัวเลข yaw ดิบจึงไม่ใช่
ตัวชี้ทิศที่เห็น สิ่งที่แบ่ง 1-vs-6 จริงคือ **ทิศที่ mesh หันเทียบกับ attachment** ซึ่งวัดได้ทางเดียวคือดูภาพ
(step 3) — และ `White Cat` มีหลักฐานเชิงตำแหน่งยืนยันซ้ำอีกชั้น

### สิ่งที่ runtime ทำกับข้อมูลชุดนี้ (จาก `PetClient.client.lua`)

```
facingCorrection = FacingAttachment.CFrame:Inverse() = CFrame.Angles(0, -π, 0)
FollowerRoot.CFrame = base * CFrame.Angles(0, -π, 0)
```
→ `FacingAttachment.WorldCFrame` = `base` พอดี (ถูกโดยนิยาม) ทิศที่ตาเห็นจึงเป็นผลของ
**ความสัมพันธ์ระหว่าง mesh กับ attachment ที่ถูก bake ค้างไว้** ไม่ใช่ผลของโค้ด — ตรงกับดีไซน์

---

## 3) Play-test baseline

**ผู้ใช้ยืนยันจาก Studio play-test รอบนี้ (Ctrl+S → Play → equip):**
`Dog` **หันก้นออก** ตามที่ผู้เล่นเดิน / `White Cat` **หันหน้าออก** ในมุมกล้องเดียวกัน
→ ตรงกับ `bugfix.md` 1.1–1.4 และยืนยัน `isBugCondition(Dog) = true`, `isBugCondition(WhiteCat) = false`

## 4) Output warn audit

**เงียบทั้ง 7 ตัว — ผู้ใช้ยืนยันจาก F9/Output ว่าไม่มี warn ของ `[PetClient]` โผล่เลย**
ตรงกับที่ derive ได้จากเงื่อนไข warn ใน `PetClient.client.lua`:

- `warn("… PrimaryPart was not FollowerRoot")` ยิงเมื่อ `src.PrimaryPart ~= FollowerRoot` → เท็จทั้ง 7
- `warn("… missing FacingAttachment")` ยิงเมื่อ `FollowerRoot and not FacingAttachment` → เท็จทั้ง 7

→ ระบบ **เงียบแล้วแสดงทิศผิด** ซึ่งเป็นสิ่งที่ requirement 2.5 ห้ามไว้ และเข้ากับ Hypothesis 1

---

## Hypothesis verdict

| # | Hypothesis | ผล | หลักฐาน |
|---|---|---|---|
| **1** | **ข้อความชี้ทางใน `CalibratePetOrientation.lua` ขัดกัน → bake geometry กลับด้าน 180°** | **ยืนยัน (ตัวจริง)** | tier/attachment เท่ากันเป๊ะทั้ง 7 → ตัวแปรที่เหลือมีแต่ geometry; `White Cat` ตัวเดียวที่หัวอยู่ฝั่ง `+Z` ของ attachment; `bakeStation` ตรวจแค่ว่า `FollowerRoot` ไม่ถูกหมุน ไม่ได้ตรวจ geometry-vs-attachment เลย จึงปล่อยความผิด 180° ผ่านเงียบ ๆ |
| 2 | เพ็ต 6 ตัวยังเป็น gen1 (ไม่มี `FacingAttachment`) | **หักล้าง** | ทั้ง 7 ตัวมี `FacingAttachment` ครบ + `PrimaryPart == FollowerRoot` ครบ |
| 3 | `FacingOffset*` ที่แก้ 180° ถูก strip | **หักล้าง** | ไม่มีตัวใดเหลือ attribute เลย รวมทั้ง `White Cat` → uniform ไม่ใช่ตัวแยก 1-vs-6 |
| 4 | `PrimaryPart` ไม่ใช่ `FollowerRoot` | **หักล้าง** | `PrimaryPart == FollowerRoot` ทั้ง 7 ตัว |
| 5 | DOM/timing race | **หักล้าง** | `facingCorrection` คำนวณครั้งเดียวจาก `src` แล้ว capture ใน closure; ข้อมูลนิ่ง อาการคงที่ |

**Root cause จริง**: geometry ของ 6 ตัวถูก bake หันสวนทาง `FacingAttachment.LookVector` ตอน SETUP
(ทำตามข้อความ `"face the red -Z marker"` ที่ขัดกับตำแหน่ง guide ที่วางไว้ local `+Z`) แล้ว `bakeStation`
ไม่มี guard จับ จึงผ่านไปเงียบ ๆ — ตรงกับ Hypothesis 1

---

## Counterexamples ที่บันทึกได้ (`isBugCondition(X) = observedFacing(X) ≠ observedFacing(WhiteCat)`)

ล้ม 6 ตัว / ผ่าน 1 ตัว — ตรงตาม EXPECTED OUTCOME

```
Dog          : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 2913594807 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
Happy Dog    : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 11727816926 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
Dark Dog     : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 11727816260 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
Black Cat    : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 11727816559 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
White Rabbit : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 11727814769 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
Pink Rabbit  : gen2 ✔ | FacingAttachment look=+Z ✔ | geometry mesh 11727815843 หันสวนทาง attachment
               → follower หันก้นออก ~180°   [FAIL]
White Cat    : gen2 ✔ | FacingAttachment look=+Z ✔ | Head อยู่ที่ relPos.Z = +0.715 = ฝั่งหน้าของ attachment
               → follower หันหน้าออก        [PASS — known-good baseline]
```

Warn ใน Output: **เงียบทั้ง 7** → ละเมิด 2.5 (เงียบแล้วแสดงผิด)

## ผลต่อขั้นถัดไป

- ทิศทางซ่อมตามดีไซน์ยังใช้ได้ **ไม่ต้องตั้งสมมติฐานใหม่** — Hypothesis 1 ยืนยันแล้ว
- 3.1 ต้องแก้ข้อความชี้ทาง **และ** เพิ่ม guard geometry-vs-attachment ใน `bakeStation` (guard คือสิ่งที่
  ขาดไปและทำให้ความผิดนี้เงียบ)
- 3.2 หมุน **`Visuals`** 180° ให้หน้าชี้ไปทางลูกบอลเหลือง — **ห้ามหมุน `FollowerRoot`** และ
  **ห้ามแตะ `FacingAttachment.CFrame`** เพราะมันถูกอยู่แล้วเท่ากันทั้ง 7 ตัว
- `SCOPE = "SELECTED"` เท่านั้น (`White Cat` ต้องไม่ถูกลากเข้ามา)
