#NoEnv
#Persistent
#SingleInstance Force
SetBatchLines, -1
SendMode Input

; ───── KeyAuth Config ─────
KA_Name := "6711"
KA_OwnerID := "4lxeiao9lE"
KA_Secret := "93637565b66c7aec537f431c40f05e63c69960b71dbef76b06fe02cd8395de4c"
KA_Version := "1.0"
KA_SessionID := ""

isAuthed := false
username := ""
userExpiry := ""

; ───── INIT ─────
KeyAuth_Init()
StartServer()

Hotkey, F10, ToggleScript
Hotkey, F5, OpenGUI
return

; ───── HWID ─────
GetHWID() {
    RunWait, %ComSpec% /c wmic csproduct get uuid > %A_Temp%\hwid.txt,, Hide
    FileRead, hwid, %A_Temp%\hwid.txt
    return Trim(StrReplace(hwid, "UUID"))
}

; ───── KeyAuth ─────
KeyAuth_Init() {
    global KA_Name, KA_OwnerID, KA_Secret, KA_Version, KA_SessionID
    url := "https://keyauth.win/api/1.2/?type=init&name=" KA_Name "&ownerid=" KA_OwnerID "&secret=" KA_Secret "&version=" KA_Version
    http := ComObjCreate("MSXML2.XMLHTTP")
    http.Open("GET", url, false)
    http.Send()
    res := http.responseText

    if (InStr(res, "success")) {
        KA_SessionID := GetJsonValue(res, "sessionid")
        return true
    }
    MsgBox, INIT FAILED
    ExitApp
}

KeyAuth_Login(user, pass) {
    global KA_Name, KA_OwnerID, KA_SessionID, username, userExpiry

    hwid := GetHWID()

    url := "https://keyauth.win/api/1.2/?type=login"
        . "&name=" KA_Name
        . "&ownerid=" KA_OwnerID
        . "&sessionid=" KA_SessionID
        . "&username=" user
        . "&pass=" pass
        . "&hwid=" hwid

    http := ComObjCreate("MSXML2.XMLHTTP")
    http.Open("GET", url, false)
    http.Send()
    res := http.responseText

    if (InStr(res, "success")) {
        username := user
        userExpiry := GetJsonValue(res, "expiry")
        return true
    }
    return false
}

GetJsonValue(json, key) {
    needle := Chr(34) . key . Chr(34) . ":" . Chr(34)
    pos := InStr(json, needle)
    if (!pos)
        return ""
    pos += StrLen(needle)
    end := InStr(json, Chr(34), false, pos)
    return SubStr(json, pos, end - pos)
}

; ───── SERVER ─────
StartServer() {
    global server
    port := 8080

    VarSetCapacity(wsaData, 394, 0)
    DllCall("ws2_32\WSAStartup", "ushort", 0x0202, "ptr", &wsaData)
    server := DllCall("ws2_32\socket", "int", 2, "int", 1, "int", 6, "ptr")

    VarSetCapacity(addr, 16, 0)
    NumPut(2, addr, 0, "short")
    NumPut(DllCall("ws2_32\htons", "ushort", port), addr, 2, "ushort")

    DllCall("ws2_32\bind", "ptr", server, "ptr", &addr, "int", 16)
    DllCall("ws2_32\listen", "ptr", server, "int", 10)

    SetTimer, HandleHTTP, 10
}

HandleHTTP:
    global server, isAuthed
    client := DllCall("ws2_32\accept", "ptr", server, "ptr", 0, "ptr", 0)
    if (client = -1)
        return

    VarSetCapacity(buffer, 8192, 0)
    DllCall("ws2_32\recv", "ptr", client, "ptr", &buffer, "int", 8192, "int", 0)
    request := StrGet(&buffer, "UTF-8")

    ; ───── LOGIN ─────
    if InStr(request, "GET /login") {
        user := GetQueryParam(request, "user")
        pass := GetQueryParam(request, "pass")

        ok := KeyAuth_Login(user, pass)

        if (ok) {
            isAuthed := true
            SendJSON(client, "{""ok"":true}")
        } else {
            SendJSON(client, "{""ok"":false}")
        }
    }

    ; ───── AUTH STATUS ─────
    else if InStr(request, "GET /authstatus") {
        SendJSON(client, "{""authed"":" (isAuthed ? "true" : "false") "}")
    }

    ; ───── READY ─────
    else if InStr(request, "GET /ready") {
        SendJSON(client, "{""ok"":true}")
    }

    ; ───── DEFAULT GUI ─────
    else {
        FileRead, html, % A_ScriptDir "\gui.html"
        header := "HTTP/1.1 200 OK`r`nContent-Type: text/html`r`n`r`n"
        DllCall("ws2_32\send", "ptr", client, "astr", header . html, "int", StrLen(header . html), "int", 0)
    }

    DllCall("ws2_32\closesocket", "ptr", client)
return

GetQueryParam(request, key) {
    RegExMatch(request, key . "=([^& ]+)", m)
    return m1
}

SendJSON(sock, json) {
    header := "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`n`r`n"
    DllCall("ws2_32\send", "ptr", sock, "astr", header . json, "int", StrLen(header . json), "int", 0)
}

; ───── HOTKEYS ─────
ToggleScript:
    if (!isAuthed) {
        MsgBox, Please login first.
        return
    }
    MsgBox, Script Enabled
return

OpenGUI:
    Run, http://127.0.0.1:8080
return