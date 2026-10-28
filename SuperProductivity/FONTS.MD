# เปลี่ยนฟอนต์ UI ของ Super Productivity เป็น Athiti-Bold

บันทึกวิธีที่ใช้จริง เมื่อ 28/10/2026 — Super Productivity 19.3.0 (MSIX จาก Store) บน Windows, ฟอนต์ Athiti ติดตั้งแบบ per-user

ผลลัพธ์: UI ทั้งแอปใช้ `Athiti-Bold`, ไอคอนยังเป็น Material Symbols, ไม่มีการแก้ไฟล์ของแอปแม้แต่ไฟล์เดียว


## สรุปสั้น (TL;DR)

แอปนี้มีระบบ **Custom Theme (CSS)** อยู่ในตัวอยู่แล้ว (Settings → Misc → Theme → Install theme) ซึ่งโหลด CSS ขึ้นมาเป็น `<style id="custom-theme-stylesheet">` ทับ UI

ดังนั้นไม่ต้องแตะ `.lnk` หรือไฟล์ใน `WindowsApps` เลย — แค่สร้างธีม CSS ที่เปลี่ยนฟอนต์ แล้วติดตั้งผ่าน 2 ทาง:

- ทางมือ: กด `Install theme` แล้วเลือกไฟล์ `.css`
- ทาง automate (ที่ใช้ในรอบนี้): เปิดแอปด้วย CDP port ชั่วคราว แล้วเขียน record ลง IndexedDB + ตั้ง `localStorage.CUSTOM_THEME` ให้ชี้มาที่ธีมเรา → reload


## ทำไมแก้ `.lnk` หรือไฟล์แอปไม่ได้

- Windows ไม่มีการตั้งฟอนต์รายไอคอน — `.lnk` ไม่มีที่เก็บฟอนต์ของตัวเอง
- `.lnk` นี้เป็น shortcut ของ UWP/MSIX app (อ่าน target แบบ normal shortcut ได้ค่าว่าง ต้องแกะ AppUserModelId จาก string ในไฟล์: `53707johannesjo.SuperProductivity_ch45amy23cdv6!SuperProductivity`)
- ตัวแอปอยู่ที่ `C:\Program Files\WindowsApps\53707johannesjo.SuperProductivity_19.3.0.0_x64__ch45amy23cdv6\app\resources\app.asar` ซึ่งถูก ACL + digital signature คุ้มครอง, ผู้ใช้ไม่ใช่ admin → แพตช์ไฟล์ = ทางตัน และจะโดนทับทุกครั้งที่อัปเดต


## หลักการที่ทำให้ CSS สั้นแค่ไม่กี่สิบบรรทัดแล้วคุมทั้งแอปได้

โครง renderer ของแอปเป็น Angular + Electron และมีจุดสำคัญ 4 จุด

- ฟอนต์หลักของทั้งแอปมาจากตัวแปรเดียว `--font-primary-stack` (ประกาศใน `:root` ของ `styles-*.css`)
- แต่ `html, body` มีคลาส `.mat-typography` และ Angular Material ตั้ง `font-family` เป็น literal stack ด้วย selector ระดับ class → ชนะ `var()` ที่มาจาก selector ระดับ element จึงต้องทับด้วย `!important`
- คอมโพเนนต์ Material หลายตัวเรียก `var(--mat-sys-*-font)` ซึ่งแอปนี้ไม่ได้ define ไว้ → declaration เป็น invalid → ตกไปใช้ฟอนต์ default ของเบราว์เซอร์ (Arial) จึงต้องทับที่ระดับ element ไม่ใช่แค่ตัวแปร
- ไอคอนคือ `<mat-icon class="material-icons mat-ligature-font">` ที่ใช้ฟอนต์ `Material Symbols Outlined` → ถ้าใช้ `*` ทับหมด ไอคอนจะกลายเป็นตัวหนังสือทันที ต้องยกเว้น


## ขั้นตอนที่ทำจริง


### 1. ยืนยันปลายทางของ shortcut และที่ติดตั้ง

```powershell
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut("C:\Users\Bazer\Desktop\Super Productivity.lnk")
# TargetPath ว่าง = shortcut ของ packaged app

Get-AppxPackage -Name "53707johannesjo.SuperProductivity" |
  Select-Object PackageFullName, InstallLocation
```


### 2. เปิดแอปพร้อม CDP port (ชั่วคราว)

MSIX app ไม่รับ argument จาก shortcut แต่รับได้ผ่าน `IApplicationActivationManager` (FullTrustApplication จะได้ argument ต่อท้าย command line)

```powershell
$aumid = '53707johannesjo.SuperProductivity_ch45amy23cdv6!SuperProductivity'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IApplicationActivationManager
{
    IntPtr ActivateApplication([In] string appUserModelId, [In] string arguments, [In] int options, [Out] out uint processId);
    IntPtr ActivateForFile([In] string appUserModelId, [In] object desktopItemArray, [In] string verb, [Out] out uint processId);
    IntPtr ActivateForProtocol([In] string appUserModelId, [In] object desktopItemArray, [Out] out uint processId);
}

public static class MsixLauncher
{
    public static uint Launch(string aumid, string arguments)
    {
        Type t = Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"));
        IApplicationActivationManager mgr = (IApplicationActivationManager)Activator.CreateInstance(t);
        uint pid;
        mgr.ActivateApplication(aumid, arguments, 0, out pid);
        return pid;
    }
}
"@

[MsixLauncher]::Launch($aumid, '--remote-debugging-port=9222')
```

จากนั้นรอ `http://127.0.0.1:9222/json/list` ตอบ (ใช้ `Invoke-RestMethod` วน poll)


### 3. ต่อ CDP แล้วอ่านสถานะธีมปัจจุบัน

`Runtime.evaluate` ตัวนี้บอกว่าแอปกำลังใช้ธีมอะไร และฟอนต์ปัจจุบันคืออะไร

```js
(() => {
  const el = document.getElementById("custom-theme-stylesheet");
  return JSON.stringify({
    href: el ? el.getAttribute("href") : null,
    tag: el ? el.tagName : null,
    lsTheme: localStorage.getItem("CUSTOM_THEME"),
    bodyFont: getComputedStyle(document.body).fontFamily,
  });
})();
```

ถ้า `href` มีค่า (เช่น `assets/themes/liquid-glass.css`) แปลว่าผู้ใช้เลือก builtin theme อยู่ ให้เอาเนื้อไฟล์นั้นมา prepend ก่อน CSS ฟอนต์ เพื่อไม่ให้สี/หน้าตาเดิมหาย (เพราะ user theme จะ **แทนที่** builtin theme ที่เลือกอยู่)


### 4. เขียน record ลง IndexedDB + ตั้งธีมให้ active

โครงข้อมูลที่แอปใช้ (อ่านจาก bundle)

- DB: `SUPThemes` version `1`
- store: `themes`, `keyPath: "id"`
- record: `{ id, name, css, uploadDate, warnings? }`
- ตัวชี้ธีมที่ active: `localStorage["CUSTOM_THEME"]` ค่าเป็น `kind:id` เช่น `user:athiti-bold`
- style element ที่แอปสร้าง: `id="custom-theme-stylesheet"`

```js
(async () => {
  const id = "athiti-bold";
  const css = `...CSS ที่ประกอบแล้ว...`;
  const db = await new Promise((res, rej) => {
    const req = indexedDB.open("SUPThemes", 1);
    req.onupgradeneeded = () => {
      try { req.result.createObjectStore("themes", { keyPath: "id" }); } catch (e) {}
    };
    req.onsuccess = () => res(req.result);
    req.onerror = () => rej(String(req.error));
  });
  await new Promise((res, rej) => {
    const tx = db.transaction("themes", "readwrite");
    tx.objectStore("themes").put({ id, name: "Athiti Bold", css, uploadDate: Date.now() });
    tx.oncomplete = () => res();
    tx.onerror = () => rej(String(tx.error));
  });
  localStorage.setItem("CUSTOM_THEME", "user:" + id);
  return "ok";
})();
```


### 5. reload แล้วตรวจผล

`Page.reload` แล้ววัด computed style — ต้องได้ครบ 3 อย่าง

- `body` / `button` / `.nav-item` ขึ้นต้นด้วย `Athiti-Bold`
- `mat-icon` ยังเป็น `"Material Symbols Outlined"`
- `localStorage.CUSTOM_THEME` = `user:athiti-bold`

ภาพหน้าจอยืนยันด้วย `Page.captureScreenshot` (ได้ PNG กลับมาเป็น base64)


### 6. ปิดรอบ debug แล้วเปิดแอปตามปกติ

ปิดด้วย `Browser.close` (หรือปิดหน้าต่าง) แล้วเปิดผ่าน shortcut ธรรมดา — ธีมจะถูก `applyActiveTheme()` อ่านจาก IndexedDB ตอน startup เอง


## CSS ที่ใช้จริง

ตัว validator ของแอปห้าม `@import`, `url()`, `image()`, `image-set()` และจำกัดขนาด 512 KB — CSS ข้างล่างผ่านทั้งหมด

```css
:root {
  --font-primary-stack: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif;
}

/* html/body ก็มี .mat-typography ที่ตั้ง literal stack ชนะ var */
html,
body {
  font-family: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif !important;
  font-synthesis-weight: none;
}

/* ทุก element ยกเว้นตัวไอคอน */
body
  :not(mat-icon):not(.material-icons):not(.material-symbols-outlined):not(
    .material-symbols-rounded
  ):not(.material-symbols-sharp) {
  font-family: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif !important;
}

/* คง monospace ตามที่แอปต้องการ (log, code, url) */
body :is(code, kbd, pre, samp, .logs-textarea, .manual-url) {
  font-family: var(--font-mono-stack) !important;
}

/* ไอคอนต้องได้ฟอนต์ glyph เสมอ */
mat-icon,
.material-icons,
.material-symbols-outlined,
.material-symbols-rounded,
.material-symbols-sharp {
  font-family: "Material Symbols Outlined", sans-serif !important;
}
```


## กับดักที่เจอระหว่างทาง

- **แค่ `:root` ตัวแปรเดียวไม่พอ** — body มี `.mat-typography` ที่ฝัง literal stack ไว้ specificity สูงกว่า จึงต้องมีกฎ `html, body` แบบ `!important` อีกชั้น
- **ปุ่มกลายเป็น Arial** — เพราะ Material components อ้าง `--mat-sys-*-font` ที่แอปไม่ได้ define → invalid → UA default ไม่ใช่ปัญหาของธีมเรา แต่ต้องแก้ด้วยการทับที่ element
- **ถ้าใช้ `body *` ตรง ๆ ไอคอนพัง** — `mat-icon` ใช้ฟอนต์ Material Symbols ถ้าโดนทับจะเหลือตัวอักษร ligature เช่น `wb_sunny` เต็มหน้าจอ
- **Bold ซ้อน Bold** — `Athiti-Bold` เป็น family เดี่ยวที่น้ำหนัก 400 ถ้าปล่อยให้เบราว์เซอร์ synthesize ตัวหนาจะหนาซ้อน จึงใส่ `font-synthesis-weight: none`
- **user theme แทน builtin theme** — ถ้าผู้ใช้เลือกธีมสีอื่นอยู่ ต้อง inline CSS ของธีมนั้นไว้ในไฟล์เดียวกัน ไม่งั้นหน้าตาจะกลับไป default
- **ชื่อ family ต้องตรงเป๊ะ** — บนเครื่องนี้มีทั้ง `Athiti` (มี Bold เป็น style) และ `Athiti-Bold` (standalone) เรียกผิดชื่อจะเงียบ ๆ fallback ไป Segoe UI


## ถอนหรือย้อนกลับ

- ในแอป: Settings → Misc → Theme → `Default` (หรือ `Remove theme`) แล้วธีม `Athiti Bold` จะหายไป
- ลบ record ตรง ๆ: ลบ key `athiti-bold` ใน IndexedDB `SUPThemes` / store `themes` แล้วล้าง `localStorage.CUSTOM_THEME`
- ธีมที่ติดตั้งแล้วจะอยู่รอดข้ามการอัปเดตแอป (ไม่ผูกกับไฟล์ใน `WindowsApps`) แต่ถ้าติดตั้งแอปใหม่/ล้างโปรไฟล์ ต้องทำซ้ำ


## ไฟล์ประกอบจากรอบที่ทำ

เก็บไว้ที่ `C:\Users\Bazer\AppData\Local\Temp\bazer\athiti\`

- `font.css` — CSS ธีมตัวจริง (คัดลอกได้ทันทีถ้าจะติดตั้งด้วยมือ)
- `launch.ps1` — เปิดแอปพร้อม `--remote-debugging-port=9222`
- `install-theme.mjs` — ติดตั้งธีมครั้งแรก (ประกอบ base theme + ฟอนต์, เขียน IDB, reload, verify, ปิดแอป)
- `apply.mjs` — อัปเดต CSS ของธีมที่ติดตั้งแล้ว + verify
- `shot.mjs` — จับภาพหน้าจอผ่าน CDP
- `diag.mjs`, `diag2.mjs` — ใช้ไล่หาว่าใครเป็นคนตั้ง `font-family` ทับ (ไล่ `document.styleSheets` + computed style)


## ข้อจำกัดที่ยังไม่ได้ตรวจ

- ไม่ได้ไล่ดูทุกหน้าจอ (dialog, ฟอร์ม, ตาราง, สลับ light/dark) — ถ้ามีจุดที่ยังไม่เปลี่ยน selector อาจต้องเพิ่ม
- วิธีนี้พึ่ง `--remote-debugging-port` ซึ่งเปิดเฉพาะตอนติดตั้ง/แก้ธีม ถ้าแอปอัปเดตแล้วโครง IndexedDB เปลี่ยน (ชื่อ DB/store) ต้องอ่าน bundle ใหม่
