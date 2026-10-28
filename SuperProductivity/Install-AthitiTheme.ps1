# ติดตั้งฟอนต์ Athiti-Bold ให้ Super Productivity (สำหรับคนที่ยังไม่เคยทำ)
# หลักการ: ใช้ระบบ Custom Theme ของแอปเอง ไม่แก้ไฟล์ใน WindowsApps
# ต้องรันคู่กับ APPLY-ATHITI-FONT.bat (หรือรันไฟล์นี้ตรง ๆ ก็ได้)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$aumid = '53707johannesjo.SuperProductivity_ch45amy23cdv6!SuperProductivity'
$themeId = 'athiti-bold'
$themeName = 'Athiti Bold'
$fontFamilies = @('Athiti-Bold', 'Athiti')
$manualCssPath = Join-Path $env:TEMP 'Athiti-Bold.theme.css'

$fontCss = @'
:root {
  --font-primary-stack: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif;
}

html,
body {
  font-family: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif !important;
  font-synthesis-weight: none;
}

body
  :not(mat-icon):not(.material-icons):not(.material-symbols-outlined):not(
    .material-symbols-rounded
  ):not(.material-symbols-sharp) {
  font-family: "Athiti-Bold", "Athiti", "Segoe UI", sans-serif !important;
}

body :is(code, kbd, pre, samp, .logs-textarea, .manual-url) {
  font-family: var(--font-mono-stack) !important;
}

mat-icon,
.material-icons,
.material-symbols-outlined,
.material-symbols-rounded,
.material-symbols-sharp {
  font-family: "Material Symbols Outlined", sans-serif !important;
}
'@

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Line { Write-Host ('-' * 64) -ForegroundColor DarkGray }

function Stop-App {
    $procs = Get-Process 'Super Productivity' -ErrorAction SilentlyContinue
    if (-not $procs) { return }
    Say '  ปิดแอปที่เปิดอยู่ก่อน…' Yellow
    $procs | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    for ($i = 0; $i -lt 24; $i++) {
        if (-not (Get-Process 'Super Productivity' -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 500
    }
    Get-Process 'Super Productivity' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

function Start-App { Start-Process "shell:AppsFolder\$aumid" }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IApplicationActivationManager2
{
    IntPtr ActivateApplication([In] string appUserModelId, [In] string arguments, [In] int options, [Out] out uint processId);
    IntPtr ActivateForFile([In] string appUserModelId, [In] object desktopItemArray, [In] string verb, [Out] out uint processId);
    IntPtr ActivateForProtocol([In] string appUserModelId, [In] object desktopItemArray, [Out] out uint processId);
}

public static class AthitiLauncher
{
    public static uint Launch(string aumid, string arguments)
    {
        Type t = Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"));
        IApplicationActivationManager2 mgr = (IApplicationActivationManager2)Activator.CreateInstance(t);
        uint pid;
        mgr.ActivateApplication(aumid, arguments, 0, out pid);
        return pid;
    }
}
"@

$script:cdpId = 0

function Receive-CdpText($ws) {
    $buf = New-Object byte[] 131072
    $sb = New-Object System.Text.StringBuilder
    do {
        $seg = [System.ArraySegment[byte]]::new($buf)
        $res = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        if ($res.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'CDP ปิดการเชื่อมต่อ' }
        [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $res.Count))
    } while (-not $res.EndOfMessage)
    return $sb.ToString()
}

function Send-Cdp($ws, $method, $params) {
    $script:cdpId++
    $payload = @{ id = $script:cdpId; method = $method; params = $params } | ConvertTo-Json -Depth 30 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    [void]$ws.SendAsync($seg, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    while ($true) {
        $obj = (Receive-CdpText $ws) | ConvertFrom-Json
        if ($obj.id -eq $script:cdpId) { return $obj }
    }
}

function Eval-Js($ws, $expression) {
    $r = Send-Cdp $ws 'Runtime.evaluate' @{ expression = $expression; awaitPromise = $true; returnByValue = $true; userGesture = $true }
    if ($r.result.exceptionDetails) {
        throw ('JavaScript error: ' + ($r.result.exceptionDetails | ConvertTo-Json -Depth 8 -Compress))
    }
    return $r.result.result.value
}

function Show-Manual {
    Say ''
    Say '  ทำมือแทนได้ง่าย ๆ (ประมาณ 20 วินาที):' Cyan
    Say '    1) เปิด Super Productivity'
    Say '    2) ไปที่ Settings (ไอคอนเฟืองมุมซ้ายล่าง) > Misc > Theme'
    Say '    3) กดปุ่ม Install theme แล้วเลือกไฟล์:'
    Say "       $manualCssPath" White
    Say '    4) กด OK/Reload ถ้าแอปถาม'
    Say ''
    Say '  ไฟล์ CSS ถูกวางไว้ให้แล้ว (ถ้าไม่มี ให้รันสคริปต์นี้อีกครั้ง)'
}

Line
Say '  ติดตั้งฟอนต์ Athiti-Bold ให้ Super Productivity' Cyan
Say '  (ใช้ระบบ Custom Theme ของแอป — ไม่แตะไฟล์โปรแกรม)'
Line
Say ''

# 1) ตรวจแอป
$pkg = Get-AppxPackage -Name '53707johannesjo.SuperProductivity' -ErrorAction SilentlyContinue
if (-not $pkg) {
    Say '  [X] ไม่พบ Super Productivity (แบบ MSIX/Store) บนเครื่องนี้' Red
    Say '      ถ้าติดตั้งแบบอื่น ให้ใช้วิธีทำมือใน FONTS.MD' Yellow
    Say ''
    exit 1
}
Say ("  พบแอป: Super Productivity " + $pkg.Version) DarkGray

# 2) ตรวจฟอนต์
Add-Type -AssemblyName System.Drawing
$installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
$haveFont = $false
foreach ($f in $fontFamilies) { if ($installed -contains $f) { $haveFont = $true } }
if (-not $haveFont) {
    Say '  [X] ยังไม่มีฟอนต์ Athiti ในเครื่อง' Red
    Say '      ติดตั้งฟอนต์ก่อน (Athiti จาก Google Fonts) แล้วรันสคริปต์นี้อีกครั้ง' Yellow
    Say ''
    exit 1
}
Say '  พบฟอนต์: Athiti-Bold' DarkGray

# 3) เตรียมไฟล์ CSS สำรองไว้ใช้ทำมือ
try { Set-Content -Path $manualCssPath -Value $fontCss -Encoding UTF8 } catch { }

# 4) ปิดแอปเดิม (ถ้าอยากให้ธีมมีผลตั้งแต่เปิดรอบแรก)
Stop-App

# 5) เปิดแอปพร้อม CDP ชั่วคราว
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()

Say "  เปิดแอปชั่วคราวเพื่อติดตั้ง (port $port)…" Yellow
[AthitiLauncher]::Launch($aumid, "--remote-debugging-port=$port") | Out-Null

$wsUrl = $null
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Milliseconds 700
    try {
        $list = Invoke-RestMethod "http://127.0.0.1:$port/json/list" -TimeoutSec 2
        $page = $list | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl } | Select-Object -First 1
        if ($page) { $wsUrl = $page.webSocketDebuggerUrl; break }
    } catch { }
}

if (-not $wsUrl) {
    Say '  [X] เปิดแอปแบบ debug ไม่สำเร็จ' Red
    Stop-App
    Start-App
    Show-Manual
    exit 1
}

# 6) ต่อ CDP แล้วติดตั้งธีม
$ws = [System.Net.WebSockets.ClientWebSocket]::new()
try {
    [void]$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    Send-Cdp $ws 'Runtime.enable' @{} | Out-Null

    $fontCssJson = ConvertTo-Json $fontCss -Compress
    $themeIdJson = ConvertTo-Json $themeId -Compress
    $themeNameJson = ConvertTo-Json $themeName -Compress

    $installJs = @'
(async () => {
  const FONT = __FONT__;
  const id = __ID__;
  const name = __NAME__;
  const el = document.getElementById('custom-theme-stylesheet');

  // เก็บธีมที่มีอยู่เดิมไว้ (ถ้ามี) เพื่อไม่ให้สี/หน้าตาเปลี่ยน
  let base = '';
  let baseSource = 'none';
  if (el && el.tagName === 'STYLE') {
    base = el.textContent || '';
    baseSource = 'style';
    // ถ้าเป็นธีม Athiti ที่ติดตั้งไว้แล้ว รันซ้ำจะได้ไม่ต้องต่อ CSS ซ้ำ
    if (base.indexOf('"Athiti-Bold"') !== -1) {
      base = '';
      baseSource = 'previous-athiti';
    }
  } else if (el && el.tagName === 'LINK') {
    try {
      const sheet = [...document.styleSheets].find(s => s.href === el.href);
      if (!sheet) throw new Error('ไม่พบ stylesheet ของธีมปัจจุบัน');
      base = [...sheet.cssRules].map(r => r.cssText).join('\n');
      baseSource = 'link';
    } catch (e) {
      return JSON.stringify({ error: 'อ่านธีมปัจจุบันไม่ได้: ' + e.message });
    }
  }

  let css = (base ? base.trimEnd() + '\n\n' : '') + FONT;
  let droppedBase = false;
  if (/@import/i.test(css) || /url\s*\(/i.test(css) || /image\(/i.test(css) || /image-set\(/i.test(css)) {
    css = FONT;
    droppedBase = true;
  }

  const db = await new Promise((res, rej) => {
    const req = indexedDB.open('SUPThemes', 1);
    req.onupgradeneeded = () => { try { req.result.createObjectStore('themes', { keyPath: 'id' }); } catch (e) {} };
    req.onsuccess = () => res(req.result);
    req.onerror = () => rej(String(req.error));
  });
  await new Promise((res, rej) => {
    const tx = db.transaction('themes', 'readwrite');
    tx.objectStore('themes').put({ id, name, css, uploadDate: Date.now() });
    tx.oncomplete = () => res();
    tx.onerror = () => rej(String(tx.error));
  });
  const stored = await new Promise((res, rej) => {
    const tx = db.transaction('themes', 'readonly');
    const r = tx.objectStore('themes').get(id);
    r.onsuccess = () => res(r.result ? r.result.css.length : -1);
    r.onerror = () => rej(String(r.error));
  });
  localStorage.setItem('CUSTOM_THEME', 'user:' + id);

  return JSON.stringify({ baseSource, baseChars: base.length, totalChars: stored, droppedBase });
})()
'@

    $installJs = $installJs.Replace('__FONT__', $fontCssJson).Replace('__ID__', $themeIdJson).Replace('__NAME__', $themeNameJson)

    $raw = Eval-Js $ws $installJs
    $info = $raw | ConvertFrom-Json
    if ($info.error) { throw $info.error }

    Say ("  เขียนธีมแล้ว: " + $info.totalChars + " ตัวอักษร (ธีมเดิม: " + $info.baseSource + ")") Green
    if ($info.droppedBase) { Say '  หมายเหตุ: ธีมสีเดิมอ่านไม่ได้ จึงใช้เฉพาะฟอนต์' Yellow }

    # 7) reload แล้วตรวจผล
    Send-Cdp $ws 'Page.enable' @{} | Out-Null
    Send-Cdp $ws 'Page.reload' @{} | Out-Null

    $verified = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 1200
        try {
            $probe = Eval-Js $ws @'
(() => {
  const font = document.body ? getComputedStyle(document.body).fontFamily : null;
  const iconEl = document.querySelector('mat-icon');
  const themeEl = document.getElementById('custom-theme-stylesheet');
  return JSON.stringify({
    ready: document.readyState,
    font,
    icon: iconEl ? getComputedStyle(iconEl).fontFamily : null,
    themeLen: themeEl ? themeEl.textContent.length : 0,
    active: localStorage.getItem('CUSTOM_THEME'),
  });
})()
'@
            $v = $probe | ConvertFrom-Json
            if ($v.ready -eq 'complete' -and $v.font) {
                $verified = $v
                if ($v.font -match 'athiti') { break }
            }
        } catch { }
    }

    if (-not $verified -or $verified.font -notmatch 'athiti') {
        throw 'ติดตั้งแล้วแต่ยังไม่เห็นผล (ตรวจ computed style ไม่ผ่าน)'
    }

    Say ''
    Say '  สำเร็จ — ฟอนต์ของแอปตอนนี้คือ:' Green
    Say ("    " + $verified.font) White
    if ($verified.icon) { Say ("    ไอคอน: " + $verified.icon) DarkGray }

    try { Send-Cdp $ws 'Browser.close' @{} | Out-Null } catch { }
    Start-Sleep -Milliseconds 1500
    $ws.Dispose()
}
catch {
    $err = $_.Exception.Message
    try { $ws.Dispose() } catch { }
    Say ''
    Say ('  [X] ไม่สำเร็จ: ' + $err) Red
    Stop-App
    Start-App
    Show-Manual
    Say ''
    exit 1
}

# 8) เปิดแอปตามปกติให้ผู้ใช้เห็นผล
Stop-App
Start-App
Start-Sleep -Milliseconds 1500

Line
Say '  เปิดแอปใหม่แล้ว ตรวจดูได้เลยว่าฟอนต์เปลี่ยน' Cyan
Say ''
Say '  ถ้าอยากยกเลิก: Settings > Misc > Theme > เลือก Default (หรือ Remove theme)' DarkGray
Say '  บันทึกวิธีเต็ม ๆ อยู่ที่ FONTS.MD ในโฟลเดอร์นี้' DarkGray
Line
Say ''
