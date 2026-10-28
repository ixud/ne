# เปลี่ยนฟอนต์ Simplenote (TH KoHo) — บันทึกการแกะ

แกะเมื่อ 28/10/2026 จาก shortcut `C:\Users\Bazer\Desktop\Simplenote (TH KoHo).lnk` — **อ่าน/วิเคราะห์เท่านั้น ไม่ได้แก้ไฟล์จริง**

เป้าหมายของบันทึก: รู้ว่าเครื่องนี้เปลี่ยนฟอนต์ Simplenote เป็น KoHo ได้อย่างไร เพื่อจะสลับเป็นฟอนต์อื่น (เช่น Athiti) ได้ในอนาคต


## สรุปสั้น

- ตัว `.lnk` ไม่ได้ทำอะไรกับฟอนต์ — มันแค่เปิด **Simplenote 2.27.1 แบบ portable** ที่ก๊อปมาจากแพ็กเกจ Store แล้วถูก **แพตช์ `app.asar`**
- การแพตช์ใช้เทคนิค **แทนที่ string ความยาวเท่ากัน (in-place, same length)** ใน 4 ไฟล์ → ขนาดไฟล์และ offset ใน asar header ไม่เปลี่ยน จึงไม่ต้อง unpack/repack ทั้ง 198 MB
- แอปไม่มีกลไก custom CSS หรือตั้งฟอนต์ในตัว (ตรวจ bundle แล้ว) → ทางเดียวคือแก้ใน asar
- ต้นฉบับของไฟล์ชุดเดียวกันยังอยู่ครบในแพ็กเกจ Store ใช้เทียบ/กู้คืนได้


## ตัว shortcut ชี้ไปที่ไหน

| Field | ค่า |
|---|---|
| Target | `C:\Users\Bazer\Apps\SimplenoteKoHo\Simplenote.exe` |
| Arguments | `--user-data-dir=C:\Users\Bazer\AppData\Local\Packages\22490Automattic.Simplenote_9h07f78gwnchp\LocalCache\Roaming\Simplenote` |
| Working dir | `C:\Users\Bazer\Apps\SimplenoteKoHo` |
| Icon | `C:\Users\Bazer\Apps\SimplenoteKoHo\app.ico,0` |
| Description | `Simplenote using TH KoHo font` |

ข้อสังเกต

- `--user-data-dir` ชี้เข้าโปรไฟล์ของแอป Store (`22490Automattic.Simplenote`) → portable copy ใช้ข้อมูล/โน้ตชุดเดียวกับแอป Store
- แพ็กเกจ Store เวอร์ชันเดียวกันติดตั้งอยู่ที่ `C:\Program Files\WindowsApps\22490Automattic.Simplenote_2.27.1.0_x64__9h07f78gwnchp` และ `Simplenote.exe` มีขนาดเท่ากับตัวใน `Apps\SimplenoteKoHo` เป๊ะ
- `resources\app.asar` ของทั้งสองที่มีขนาดเท่ากันเป๊ะ: **198,279,151 bytes** → portable copy คือชุดไฟล์ที่ก๊อปมาแล้วแก้เฉพาะเนื้อใน asar


## สถาปัตยกรรมที่ต้องรู้ก่อน

- Electron app (Electron ฝังใน `Simplenote.exe` 190 MB) + React + Monaco editor
- renderer อยู่ใน `resources\app.asar` (ไม่มี `app.asar.unpacked`)
- asar เก็บไฟล์แบบ raw ต่อกัน + header JSON ที่บอก `offset`/`size`/`integrity` ของทุกไฟล์ (24,159 ไฟล์, header 6,325,973 bytes, data เริ่มที่ 6,325,992)
- ไม่มีกลไก custom CSS/ฟอนต์: ค้นใน `dist/app.*.js` ไม่พบ `customCSS`, `custom-css`, `user.css` — มีแค่ธีม light/dark


## วิธีที่คนทำใช้จริง: in-place same-length patch

หลักการ: ถ้าแก้เนื้อหาไฟล์ใน asar ให้ **ความยาวเท่ากันทุกไบต์** ค่า `offset`/`size` ใน header ยังถูกต้องทั้งหมด → เปิดแอปได้เลย ไม่ต้องสร้าง asar ใหม่

หลักฐานที่ยืนยัน (จาก portable เทียบกับ Store)

- ไฟล์ที่แก้ทั้ง 4 ไฟล์มี `size` เท่ากับต้นฉบับเป๊ะ (73,763 / 128,137 / 48,952 / 126,294)
- hash SHA256 ใน header **ไม่ตรง** เฉพาะ 4 ไฟล์นี้ แต่ไฟล์อื่นสุ่มตรวจ 250 ไฟล์ตรงหมด → แก้เฉพาะจุด ไม่ได้ repack
- `integrity` เป็น SHA256 แบบ hex ต่อบล็อก (blockSize 4 MB, ไฟล์พวกนี้จึงมี 1 บล็อก)
- นับสตริงในไฟล์จริง: portable มี `TH KoHo` ครบ 5 / 2 / 1 จุดตามตาราง, Store มี `BlinkMacSystemFont"` 5 จุด และ `-apple-system,BlinkMacSystemFont` 2 จุด, ไม่มีคำว่า Athiti ในทั้งสองไฟล์

จุดที่ถูกแก้ (ค้นด้วย string ไม่ใช่ offset เพราะชื่อไฟล์มี hash เปลี่ยนตามเวอร์ชัน)

| ไฟล์ใน asar | จำนวนจุด | ต้นฉบับ (Store) | หลังแพตช์ (portable) | ยาว |
|---|---|---|---|---|
| `dist/main.45a389b133d4c315a8d2.css` | 5 | `BlinkMacSystemFont"` | `TH KoHo",sans-serif` | 19 → 19 |
| `dist/7363.45a389b133d4c315a8d2.css` | 1 | `-apple-system,BlinkMacSystemFont` | `"TH KoHo", "Segoe UI",sans-serif` | 32 → 32 |
| `dist/note-editor.2fbbb65f9f4d92bfa412.js` | 1 | `-apple-system, BlinkMacSystemFont` | `"TH KoHo", "Segoe UI", sans-serif` | 33 → 33 |
| `node_modules/monaco-editor/min/vs/editor/editor.main.css` | 1 | `-apple-system,BlinkMacSystemFont` | `"TH KoHo", "Segoe UI",sans-serif` | 32 → 32 |

ผลลัพธ์ใน `main.css` ออกมาเป็นแบบนี้ (ไม่ได้ลบของเดิม แต่ยัดชื่อใหม่ทับตำแหน่งของ fallback ตัวแรก เพราะ `-apple-system` ไม่มีบน Windows)

```
- -apple-system,"BlinkMacSystemFont","Segoe UI",...   (ต้นฉบับ)
+ -apple-system,"TH KoHo",sans-serif,"Segoe UI",...  (หลังแพตช์)
```

`-apple-system` ไม่มีบน Windows จึงตกมาที่ตัวถัดไป = ฟอนต์ที่ต้องการ


## ฟอนต์แต่ละจุดคุมอะไร

- `body` → ค่าเริ่มต้นของทั้งแอป (14px/1.5)
- `.note-list-item` → รายการโน้ต (คง `"Simplenote Tasks"` ไว้เป็นตัวแรก เพราะเป็นฟอนต์ไอคอน checkbox)
- `.note-content-editor-shell`, `.note-detail-markdown` → พื้นที่แก้โน้ตแบบ markdown
- `.note-revisions .note-revisions-content` → หน้า history
- `.tag-input input` → ช่องใส่ tag
- `.monaco-editor` (2 ไฟล์ CSS) → ตัว Monaco editor และ widget
- `dist/note-editor.*.js` → option `fontFamily` ที่ส่งให้ Monaco ตอนสร้าง editor

จุดที่ยังไม่ได้แก้ (และไม่กระทบ UI หลัก)

- `dist/7363.c1361bda1641b11a3b3e.js` และ `node_modules/monaco-editor/min/vs/editor/editor.main.js` ยังมี `-apple-system` ฝังอยู่ 7 จุดต่อไฟล์ — เป็นค่า default ภายในของ Monaco ซึ่งแอปส่ง `fontFamily` ของตัวเองทับอยู่แล้ว


## เปลี่ยนเป็น Athiti (หรือฟอนต์อื่น) ต้องทำอย่างไร

ต้องหาสตริงแทนที่ **ยาวเท่ากันเป๊ะ** ตัวอย่างที่คำนวณไว้ให้แล้ว (นับจากจุดที่แทนจริงในไฟล์)

- ช่อง 19 ตัวอักษร (อยู่ในลิสต์ต่อจากเครื่องหมายคำพูดเดิม): `Athiti", sans-serif` = 6 + 1 + 2 + 10 = **19** ✓
- ช่อง 32 ตัวอักษร: `"Athiti", "Segoe UI", sans-serif` = 8 + 2 + 10 + 2 + 10 = **32** ✓
- ช่อง 33 ตัวอักษร: `"Athiti", "Segoe UI",  sans-serif` = 8 + 2 + 10 + 3 + 10 = **33** ✓ (เว้น 2 ตัวก่อน `sans-serif` เพื่อให้ครบ)

ถ้าชื่อฟอนต์ยาวไม่ลงตัว ใช้วิธีปรับช่องว่างในลิสต์ (CSS ยอมรับช่องว่างหลัง comma) หรือเติม fallback ให้พอดี — ห้ามให้ความยาวเปลี่ยนแม้แต่ไบต์เดียว ไม่งั้น offset ทั้ง asar จะเลื่อนและแอปเปิดไม่ขึ้น

เงื่อนไขก่อนเริ่ม

- ฟอนต์ปลายทางต้องติดตั้งในเครื่องก่อน (per-user ก็ได้) — เครื่องนี้มีทั้ง `TH KoHo` และ `Athiti-Bold`
- ปิดแอปให้สนิทก่อนแก้ไฟล์
- สำรอง `app.asar` ไว้ 1 ชุด (198 MB) หรือใช้ไฟล์จาก Store package เป็นต้นฉบับคืน


## สเก็ตช์สคริปต์แพตช์ (ยังไม่ได้รัน)

```powershell
$asar = 'C:\Users\Bazer\Apps\SimplenoteKoHo\resources\app.asar'
Copy-Item $asar "$asar.bak" -Force   # สำรองก่อน

# จากสถานะปัจจุบัน (KoHo) -> Athiti ; ทุกคู่ต้องยาวเท่ากัน
$pairs = @(
  @{ old = 'TH KoHo",sans-serif';                new = 'Athiti", sans-serif';                 count = 5 },  # main.css
  @{ old = '"TH KoHo", "Segoe UI",sans-serif';    new = '"Athiti", "Segoe UI", sans-serif';    count = 2 },  # 7363.css + editor.main.css
  @{ old = '"TH KoHo", "Segoe UI", sans-serif';   new = '"Athiti", "Segoe UI",  sans-serif';   count = 1 }   # note-editor.js
)

$bytes = [IO.File]::ReadAllBytes($asar)
$text  = [Text.Encoding]::Latin1.GetString($bytes)
$before = $bytes.Length
foreach ($p in $pairs) {
  if ($p.old.Length -ne $p.new.Length) { throw "ความยาวไม่เท่า: $($p.old)" }
  $found = ([regex]::Matches($text, [regex]::Escape($p.old))).Count
  if ($found -ne $p.count) { throw "เจอ $found จุด ไม่ตรงกับที่คาด $($p.count)" }
  $text = $text.Replace($p.old, $p.new)
}
[IO.File]::WriteAllBytes($asar, [Text.Encoding]::Latin1.GetBytes($text))
if ((Get-Item $asar).Length -ne $before) { throw 'ขนาดไฟล์เปลี่ยน = offset เพี้ยน ให้คืนจาก .bak' }
```

หมายเหตุการใช้งานจริง

- สคริปต์นี้แพตช์จากสภาพ **KoHo ปัจจุบัน** → Athiti ถ้าจะเริ่มจากไฟล์ต้นฉบับ Store ให้ใช้สตริงในตาราง KoHo ด้านบนแทน
- `count` คือด่านกันพลาด: ถ้าเวอร์ชันใหม่มีจุดไม่เท่าเดิม สคริปต์จะหยุดก่อนเขียนไฟล์
- สคริปต์นี้โหลดทั้งไฟล์เป็นสตริงเพื่อ replace — ใช้หน่วยความจำราว 1 GB ตอนรัน ถ้าเครื่อง RAM น้อยให้แก้ทีละไฟล์ที่ offset แทน
- ต้องตรวจว่า `WriteAllBytes` ได้ความยาวเท่าเดิม (`(Get-Item $asar).Length`) และควร diff กับไฟล์จาก Store package อีกครั้ง
- ถ้าอยากแก้ให้ปลอดภัยกว่า: extract เฉพาะ 4 ไฟล์ออกมาแก้ แล้วเขียนกลับไปที่ offset เดิม (`dataStart + file.offset`) แทนการ replace ทั้งไฟล์


## ตรวจว่าแพตช์ติด

- เปิดแอปแล้วดูด้วยตา / จับภาพหน้าจอ
- ตรวจด้วย computed style ผ่าน DevTools (`getComputedStyle(document.body).fontFamily`) — ต้องเห็นชื่อฟอนต์ใหม่
- เทียบกับต้นฉบับ: แตกไฟล์จาก `C:\Program Files\WindowsApps\22490Automattic.Simplenote_2.27.1.0_x64__9h07f78gwnchp\app\resources\app.asar` แล้ว diff — ควรต่างกันเฉพาะ 4 จุดในตาราง
- ตรวจว่า `size` ของ 4 ไฟล์ยังเท่าเดิม และ hash ใน header จะไม่ตรง (คาดไว้แล้ว)


## ทางเลือกอื่น และเหตุผลที่ไม่เลือก

- แตก asar เป็น `resources\app` แล้วเปลี่ยนชื่อ `app.asar` ออก — แก้ซ้ำง่าย แต่ต้องดูแลไฟล์ 24,159 ไฟล์ และ Electron จะเลือกโฟลเดอร์ก็ต่อเมื่อไม่มี `app.asar`
- repack asar ใหม่ — สะอาด แต่ต้องประมวลผล ~198 MB และ hash ทั้งหมดจะเปลี่ยน (ไม่จำเป็นสำหรับแอปนี้)
- ฉีด CSS ผ่าน `--remote-debugging-port` ตอนรัน — เหมาะแค่พรีวิว เพราะไม่คงอยู่หลังปิดแอป


## ความเสี่ยง

- `electron-updater` ในตัวแอปอาจอัปเดตทับ patch (portable copy นี้ไม่ผูกกับ Store แล้ว จึงไม่มีใครอัปเดตให้ — แต่ถ้าเปิด auto-update ต้องแพตช์ซ้ำ)
- ห้ามแตะ `@font-face` ของ `"Simplenote Tasks"` (ฟอนต์ไอคอนฝัง base64) ไม่งั้น checkbox/task glyph จะพัง
- แพ็กเกจ Store ยังเป็นต้นฉบับ — ใช้เป็นแหล่งกู้คืนได้เสมอ (คัดลอก `app.asar` กลับ)
- Windows ไม่ตรวจ asar integrity ตอนรัน (พิสูจน์จาก hash ไม่ตรงแต่แอปทำงาน) แต่ถ้าย้ายไป macOS กลไกนี้เข้มกว่าและอาจเปิดไม่ขึ้น
- ชื่อไฟล์มี hash ต่อท้าย เปลี่ยนทุกเวอร์ชัน — ต้องหาไฟล์จาก pattern `dist/main.*.css`, `dist/note-editor.*.js` ทุกครั้ง


## ไฟล์ที่ใช้แกะ (เก็บใน temp)

- `C:\Users\Bazer\AppData\Local\Temp\bazer\sn-extract.js` — แตกไฟล์จาก asar ตาม path
- `C:\Users\Bazer\AppData\Local\Temp\bazer\sn-diff.js` — diff แบบหาจุดต่าง (ใช้เทียบ Store กับ portable)
- `sn-map.js`, `sn-scan.js`, `sn-deep.js`, `sn-integ.js`, `sn-sample.js` — หา offset / สแกน string / ตรวจ hash
- `bazer\sn\` (ไฟล์จาก portable) และ `bazer\sn-store\` (ไฟล์จาก Store) — ใช้เทียบกัน


## ข้อจำกัด

- บันทึกนี้มาจากการอ่านไฟล์เท่านั้น **ยังไม่มีการทดสอบแพตช์จริง** (ผู้ใช้สั่งให้แค่แกะ) — ขั้นตอนในสคริปต์ยังไม่ได้รันกับไฟล์จริง
- ตัวเลข offset/hash ที่ยกมาเป็นของเวอร์ชัน 2.27.1 บนเครื่องนี้ ไม่รับประกันกับเวอร์ชันอื่น
