; ============================================================
; Scroll Wheel Debouncer v3.5
; ============================================================
; NEW in v3.5:
;   - All settings persist across reboots via INI file
;   - wornEncoderMode, dirLockMode, showOverlay saved immediately
;     when toggled — no longer reset on next boot
; v3.5:
;   - Moved WheelUp/WheelDown hotkey blocks to TOP of file
;     (AHK v2 requires hotkey blocks before function definitions)
; NEW in v3.5:
;   - Worn Encoder Sleep Mode (Ctrl+Alt+W to toggle)
;     Adds Sleep() in discard branch only — gives M150-class
;     worn encoders the hard dead zone v2 had, without slowing
;     good scroll events. wornSleepMs default = 130ms.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ── Core params ───────────────────────────────────────────────
global reverseBlockMs := 110
global baseCN         := 2
global maxCN          := 3
global backoffStep    := 1
global decayEvery     := 1

; ── User settings (saved to INI) ──────────────────────────────
global iniFile        := A_ScriptDir . "\scroll_debouncer.ini"
global toggleHotkey   := LoadSetting("toggleHotkey",   "MButton")
global idleResetSecs  := LoadSetting("idleResetSecs",  "0")
global showOverlay    := LoadSetting("showOverlay",     "1") = "1"
global autoDetect     := LoadSetting("autoDetect",      "1") = "1"
global doubleTapMs    := LoadSetting("doubleTapMs",     "300")
global defaultDir     := LoadSetting("defaultDir",      "DOWN")

; ── Worn Encoder Mode ─────────────────────────────────────────
global wornSleepMs     := Integer(LoadSetting("wornSleepMs", "130"))
global wornEncoderMode := LoadSetting("wornEncoderMode", "0") = "1"

; ── Persisted mode state ──────────────────────────────────────
global _dirLockModeSaved := LoadSetting("dirLockMode", "0") = "1"

; ── Runtime state ─────────────────────────────────────────────
global dirLockMode    := _dirLockModeSaved
global lockedDir      := defaultDir
global middleHeld     := false
global lastDir        := ""
global pendingDir     := ""
global pendingCount   := 0
global pendingCN      := 2
global lastSentDir    := ""
global lastSentTs     := 0
global cnCurrent      := baseCN
global sameDirCount   := 0

; ── Stats ─────────────────────────────────────────────────────
global sessionPhantoms   := 0
global sessionEvents     := 0
global sessionStart      := A_TickCount
global lastScrollTs      := 0

; ── Auto-detection ────────────────────────────────────────────
global autoDetectDone     := false
global autoDetectStart    := A_TickCount
global autoDetectEvents   := 0
global autoDetectPhantoms := 0

; ── Double-tap ────────────────────────────────────────────────
global lastWheelTs  := 0
global lastWheelDir := ""

; ── Per-app memory ────────────────────────────────────────────
global appDirMemory := Map()

; ── Overlay GUI ───────────────────────────────────────────────
global overlayGui := ""

; ── Setup ─────────────────────────────────────────────────────
RegisterToggleHotkey()
HotKey("^!w", ToggleWornMode)   ; Ctrl+Alt+W — worn encoder toggle
UpdateTray()
if (showOverlay)
    CreateOverlay()
if (autoDetect)
    SetTimer(CheckAutoDetect, 2000)
SetTimer(CheckIdleReset, 1000)
SetTimer(CheckAppDir, 500)

; ============================================================
; WHEEL HOOKS  ← must come before any function definitions
; ============================================================

WheelUp:: {
    global dirLockMode, lockedDir, middleHeld, lastScrollTs
    global lastDir, pendingDir, pendingCount, pendingCN
    global lastSentDir, lastSentTs, cnCurrent, sameDirCount
    global sessionPhantoms, sessionEvents
    global reverseBlockMs, baseCN, maxCN, backoffStep, decayEvery
    global wornEncoderMode, wornSleepMs

    sessionEvents++
    lastScrollTs := A_TickCount
    CheckDoubleTap("UP")

    ; ── Direction Lock Mode ────────────────────────────────
    if (dirLockMode) {
        if (middleHeld)
            Send("{WheelUp}")
        else if (lockedDir = "UP")
            Send("{WheelUp}")
        else
            sessionPhantoms++
        return
    }

    ; ── Normal Mode ───────────────────────────────────────
    now := A_TickCount
    if (lastSentDir = "DOWN" and lastSentTs > 0 and (now - lastSentTs) < reverseBlockMs) {
        ; ── v3.5: Worn Encoder Sleep (discard branch only) ──
        if (wornEncoderMode)
            Sleep(wornSleepMs)
        sessionPhantoms++
        return
    }
    if (lastDir = "UP" or lastDir = "") {
        lastDir := "UP"
        pendingDir := ""
        pendingCount := 0
        sameDirCount++
        if (Mod(sameDirCount, decayEvery) = 0)
            cnCurrent := Max(cnCurrent - 1, baseCN)
        lastSentDir := "UP"
        lastSentTs  := now
        Send("{WheelUp}")
    } else {
        if (pendingDir != "UP") {
            pendingDir   := "UP"
            pendingCount := 1
            pendingCN    := baseCN
            sameDirCount := 0
        } else
            pendingCount++
        if (pendingCount >= pendingCN) {
            lastDir      := "UP"
            pendingDir   := ""
            pendingCount := 0
            cnCurrent    := baseCN
            lastSentDir  := "UP"
            lastSentTs   := now
            Send("{WheelUp}")
        } else {
            if (wornEncoderMode)
                Sleep(wornSleepMs)
            sessionPhantoms++
            cnCurrent := Min(cnCurrent + backoffStep, maxCN)
        }
    }
}

WheelDown:: {
    global dirLockMode, lockedDir, middleHeld, lastScrollTs
    global lastDir, pendingDir, pendingCount, pendingCN
    global lastSentDir, lastSentTs, cnCurrent, sameDirCount
    global sessionPhantoms, sessionEvents
    global reverseBlockMs, baseCN, maxCN, backoffStep, decayEvery
    global wornEncoderMode, wornSleepMs

    sessionEvents++
    lastScrollTs := A_TickCount
    CheckDoubleTap("DOWN")

    ; ── Direction Lock Mode ────────────────────────────────
    if (dirLockMode) {
        if (middleHeld)
            Send("{WheelDown}")
        else if (lockedDir = "DOWN")
            Send("{WheelDown}")
        else
            sessionPhantoms++
        return
    }

    ; ── Normal Mode ───────────────────────────────────────
    now := A_TickCount
    if (lastSentDir = "UP" and lastSentTs > 0 and (now - lastSentTs) < reverseBlockMs) {
        if (wornEncoderMode)
            Sleep(wornSleepMs)
        sessionPhantoms++
        return
    }
    if (lastDir = "DOWN" or lastDir = "") {
        lastDir      := "DOWN"
        pendingDir   := ""
        pendingCount := 0
        sameDirCount++
        if (Mod(sameDirCount, decayEvery) = 0)
            cnCurrent := Max(cnCurrent - 1, baseCN)
        lastSentDir := "DOWN"
        lastSentTs  := now
        Send("{WheelDown}")
    } else {
        if (pendingDir != "DOWN") {
            pendingDir   := "DOWN"
            pendingCount := 1
            pendingCN    := baseCN
            sameDirCount := 0
        } else
            pendingCount++
        if (pendingCount >= pendingCN) {
            lastDir      := "DOWN"
            pendingDir   := ""
            pendingCount := 0
            cnCurrent    := baseCN
            lastSentDir  := "DOWN"
            lastSentTs   := now
            Send("{WheelDown}")
        } else {
            if (wornEncoderMode)
                Sleep(wornSleepMs)
            sessionPhantoms++
            cnCurrent := Min(cnCurrent + backoffStep, maxCN)
        }
    }
}

; ============================================================
; ALL FUNCTIONS BELOW THIS LINE
; ============================================================

; ── INI helpers ───────────────────────────────────────────────

LoadSetting(key, default) {
    global iniFile
    try {
        val := IniRead(iniFile, "settings", key)
        return val
    } catch {
        return default
    }
}

SaveSetting(key, value) {
    global iniFile
    IniWrite(value, iniFile, "settings", key)
}

; ── Hotkey registration ───────────────────────────────────────

RegisterToggleHotkey() {
    global toggleHotkey
    try {
        HotKey(toggleHotkey, ToggleDirection)
    } catch {
        MsgBox("Could not register hotkey: " . toggleHotkey . "`nResetting to MButton.", "Hotkey Error")
        global toggleHotkey := "MButton"
        SaveSetting("toggleHotkey", "MButton")
        HotKey("MButton", ToggleDirection)
    }
}

; ── Direction toggle ──────────────────────────────────────────

ToggleDirection(*) {
    global dirLockMode, lockedDir, middleHeld, toggleHotkey

    if (!dirLockMode)
        return

    middleHeld := true
    ToolTip("○  FREE SCROLL")
    KeyWait(toggleHotkey)
    middleHeld := false
    ToolTip()

    if (A_TimeSinceThisHotkey < 400) {
        SaveAppDir()
        lockedDir := (lockedDir = "DOWN") ? "UP" : "DOWN"
        ShowDirectionTooltip()
        UpdateOverlay()
        UpdateTray()
    }
}

; ── Worn encoder mode toggle ──────────────────────────────────

ToggleWornMode(*) {
    global wornEncoderMode, wornSleepMs
    wornEncoderMode := !wornEncoderMode
    SaveSetting("wornEncoderMode", wornEncoderMode ? "1" : "0")
    UpdateTray()
    UpdateOverlay()
    label := wornEncoderMode
        ? "🟠 Worn Encoder Mode ON  (Sleep " . wornSleepMs . "ms)"
        : "🟢 Worn Encoder Mode OFF"
    TrayTip(label, "Scroll Debouncer v3.5", 2)
}

; ── Double-tap ────────────────────────────────────────────────

CheckDoubleTap(dir) {
    global lastWheelTs, lastWheelDir, doubleTapMs, dirLockMode, lockedDir
    now := A_TickCount
    if (lastWheelDir = dir and (now - lastWheelTs) < Integer(doubleTapMs)) {
        if (dirLockMode) {
            lockedDir := (lockedDir = "DOWN") ? "UP" : "DOWN"
            ShowDirectionTooltip()
            UpdateOverlay()
            UpdateTray()
        }
    }
    lastWheelDir := dir
    lastWheelTs  := now
}

; ── Idle reset ────────────────────────────────────────────────

CheckIdleReset() {
    global idleResetSecs, dirLockMode, lockedDir, lastScrollTs, defaultDir
    if (!dirLockMode or Integer(idleResetSecs) = 0)
        return
    if (lastScrollTs = 0)
        return
    elapsed := (A_TickCount - lastScrollTs) / 1000
    if (elapsed >= Integer(idleResetSecs) and lockedDir != defaultDir) {
        lockedDir := defaultDir
        UpdateOverlay()
        UpdateTray()
        ToolTip("↺  Reset to " . defaultDir)
        SetTimer(() => ToolTip(), -1000)
    }
}

; ── Per-app direction memory ──────────────────────────────────

CheckAppDir() {
    global dirLockMode, lockedDir, appDirMemory
    if (!dirLockMode)
        return
    try {
        app := WinGetProcessName("A")
        if (appDirMemory.Has(app)) {
            savedDir := appDirMemory[app]
            if (savedDir != lockedDir) {
                lockedDir := savedDir
                UpdateOverlay()
                UpdateTray()
            }
        }
    } catch {
    }
}

SaveAppDir() {
    global dirLockMode, lockedDir, appDirMemory
    if (!dirLockMode)
        return
    try {
        app := WinGetProcessName("A")
        appDirMemory[app] := lockedDir
    } catch {
    }
}

; ── Auto-detection ────────────────────────────────────────────

CheckAutoDetect() {
    global autoDetect, autoDetectDone, autoDetectStart
    global autoDetectEvents, autoDetectPhantoms
    global dirLockMode, sessionPhantoms, sessionEvents

    if (!autoDetect or autoDetectDone)
        return

    elapsed := (A_TickCount - autoDetectStart) / 1000
    if (elapsed < 60)
        return

    autoDetectDone := true
    SetTimer(CheckAutoDetect, 0)

    rate := sessionEvents > 0 ? (sessionPhantoms / sessionEvents * 100) : 0

    if (rate < 5) {
        health      := "Good"
        colour      := "green"
        suggestion  := "Your encoder is healthy. Normal mode is perfect."
        suggestLock := false
    } else if (rate < 40) {
        health      := "Moderate wear"
        colour      := "yellow"
        suggestion  := "Moderate encoder wear detected. Normal mode still works well."
        suggestLock := false
    } else {
        health      := "Heavy wear"
        colour      := "red"
        suggestion  := "Heavy encoder wear detected (" . Round(rate, 1) . "% phantom rate).`n`nSwitch to Direction Lock mode for best experience?`n`n(Middle click toggles scroll direction in lock mode)"
        suggestLock := true
    }

    UpdateTrayColour(colour)

    if (suggestLock) {
        result := MsgBox(suggestion, "Encoder Health Check", "YesNo Icon!")
        if (result = "Yes") {
            dirLockMode := true
            UpdateTray()
            UpdateOverlay()
        }
    } else {
        TrayTip("Encoder Health: " . health, suggestion, 3)
    }
}

UpdateTrayColour(colour) {
    global sessionPhantoms, sessionEvents
    rate       := sessionEvents > 0 ? Round(sessionPhantoms / sessionEvents * 100, 1) : 0
    colourEmoji := colour = "green" ? "🟢" : colour = "yellow" ? "🟡" : "🔴"
    A_IconTip  := colourEmoji . " Scroll Debouncer — " . rate . "% phantom rate"
}

; ── Overlay ───────────────────────────────────────────────────

CreateOverlay() {
    global overlayGui, lockedDir, dirLockMode, showOverlay
    if (!showOverlay)
        return
    if (overlayGui != "")
        try overlayGui.Destroy()

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
    overlayGui.BackColor := "000000"
    overlayGui.SetFont("s11 w600 c00ff88", "Segoe UI")
    overlayGui.Add("Text", "vDirLabel w120 Center", GetOverlayLabel())
    overlayGui.Show("NoActivate x" . (A_ScreenWidth - 130) . " y20 w130 h30")
    WinSetTransparent(200, overlayGui)
    WinSetRegion("0-0 w130 h30 r8-8", overlayGui)
}

GetOverlayLabel() {
    global dirLockMode, lockedDir, wornEncoderMode
    worn := wornEncoderMode ? " [WORN]" : ""
    if (!dirLockMode)
        return "● NORMAL" . worn
    return (lockedDir = "DOWN" ? "↓ DOWN" : "↑ UP") . worn
}

UpdateOverlay() {
    global overlayGui, showOverlay
    if (!showOverlay or overlayGui = "")
        return
    try {
        ctrl := overlayGui["DirLabel"]
        ctrl.Text := GetOverlayLabel()
    } catch {
        CreateOverlay()
    }
}

; ── Tray ──────────────────────────────────────────────────────

UpdateTray() {
    global dirLockMode, lockedDir, toggleHotkey, wornEncoderMode, wornSleepMs
    A_TrayMenu.Delete()

    if (dirLockMode) {
        dirLabel := lockedDir = "DOWN" ? "↓ DOWN" : "↑ UP"
        A_TrayMenu.Add("🔒 Direction Lock — " . dirLabel, (*) => "")
        A_TrayMenu.Add()
        A_TrayMenu.Add("→ Normal Mode", ToggleMode)
    } else {
        A_TrayMenu.Add("● Normal Mode", (*) => "")
        A_TrayMenu.Add()
        A_TrayMenu.Add("→ Direction Lock Mode", ToggleMode)
    }

    A_TrayMenu.Add()
    wornLabel := wornEncoderMode
        ? "🟠 Worn Mode ON (" . wornSleepMs . "ms)  [Ctrl+Alt+W]"
        : "⬜ Worn Encoder Mode  [Ctrl+Alt+W]"
    A_TrayMenu.Add(wornLabel, ToggleWornMode)

    A_TrayMenu.Add()
    A_TrayMenu.Add("⚙ Settings",   OpenSettings)
    A_TrayMenu.Add("📊 View Stats", ShowStats)
    A_TrayMenu.Add("🔄 Reload",     (*) => Reload())
    A_TrayMenu.Add("❌ Exit",        (*) => ExitApp())

    A_IconTip := dirLockMode
        ? "🔒 Scroll Debouncer — Lock: " . lockedDir
        : (wornEncoderMode ? "🟠 Scroll Debouncer — Worn Mode" : "● Scroll Debouncer v3.5")
}

ToggleMode(*) {
    global dirLockMode, lockedDir, defaultDir
    dirLockMode := !dirLockMode
    if (dirLockMode)
        lockedDir := defaultDir
    SaveSetting("dirLockMode", dirLockMode ? "1" : "0")
    UpdateTray()
    UpdateOverlay()
}

; ── Settings GUI ──────────────────────────────────────────────

OpenSettings(*) {
    global toggleHotkey, idleResetSecs, showOverlay
    global autoDetect, doubleTapMs, defaultDir, wornSleepMs

    settingsGui := Gui("+AlwaysOnTop", "Scroll Debouncer — Settings")
    settingsGui.SetFont("s10", "Segoe UI")

    settingsGui.Add("GroupBox", "w380 h80", "Direction Toggle Hotkey")
    settingsGui.Add("Text", "xp+10 yp+25", "Current hotkey:")
    hkEdit := settingsGui.Add("Edit", "x+10 w150", toggleHotkey)
    settingsGui.Add("Text", "xp+160 yp", "(e.g. MButton, F8, XButton1)")
    settingsGui.Add("Text", "x20 yp+20", "Double-tap scroll to toggle (ms):")
    dtEdit := settingsGui.Add("Edit", "x+10 w60", doubleTapMs)

    settingsGui.Add("GroupBox", "x10 y+15 w380 h60", "Idle Auto-Reset")
    settingsGui.Add("Text", "xp+10 yp+25", "Reset direction after idle (0=off):")
    idleEdit := settingsGui.Add("Edit", "x+10 w60", idleResetSecs)
    settingsGui.Add("Text", "x+5", "seconds")

    settingsGui.Add("GroupBox", "x10 y+15 w380 h60", "Worn Encoder Mode (v3.5)")
    settingsGui.Add("Text", "xp+10 yp+25", "Sleep after phantom discard (ms):")
    wornEdit := settingsGui.Add("Edit", "x+10 w60", wornSleepMs)
    settingsGui.Add("Text", "x+5", "(100-200; 200=v2 behaviour)")

    settingsGui.Add("GroupBox", "x10 y+15 w380 h90", "Behaviour")
    showCb   := settingsGui.Add("CheckBox", "xp+10 yp+25 Checked" . (showOverlay ? 1 : 0), "Show direction overlay (top-right corner)")
    autoCb   := settingsGui.Add("CheckBox", "xp yp+25 Checked" . (autoDetect ? 1 : 0), "Auto-detect encoder health on startup")
    settingsGui.Add("Text", "xp yp+25", "Default direction on startup / idle reset:")
    defDirDDL := settingsGui.Add("DropDownList", "x+10 w80 Choose" . (defaultDir = "DOWN" ? 1 : 2), ["DOWN","UP"])

    saveBtn := settingsGui.Add("Button", "x10 y+15 w80", "Save")
    saveBtn.OnEvent("Click", (*) => SaveSettings(
        hkEdit.Value, dtEdit.Value, idleEdit.Value,
        wornEdit.Value, showCb.Value, autoCb.Value,
        defDirDDL.Text, settingsGui
    ))
    settingsGui.Add("Button", "x+10 w80", "Cancel").OnEvent("Click", (*) => settingsGui.Destroy())
    settingsGui.Show()
}

SaveSettings(hk, dt, idle, worn, overlay, auto, defDir, gui) {
    global toggleHotkey, doubleTapMs, idleResetSecs
    global showOverlay, autoDetect, defaultDir, wornSleepMs

    try {
        if (hk != toggleHotkey)
            HotKey(toggleHotkey, "Off")
        HotKey(hk, ToggleDirection)
    } catch {
        MsgBox("Invalid hotkey: " . hk, "Error")
        return
    }

    toggleHotkey  := hk
    doubleTapMs   := dt
    idleResetSecs := idle
    wornSleepMs   := Integer(worn)
    showOverlay   := overlay = 1
    autoDetect    := auto = 1
    defaultDir    := defDir

    SaveSetting("toggleHotkey",   hk)
    SaveSetting("doubleTapMs",    dt)
    SaveSetting("idleResetSecs",  idle)
    SaveSetting("wornSleepMs",    worn)
    SaveSetting("wornEncoderMode", wornEncoderMode ? "1" : "0")
    SaveSetting("showOverlay",    overlay = 1 ? "1" : "0")
    SaveSetting("autoDetect",     auto = 1 ? "1" : "0")
    SaveSetting("defaultDir",     defDir)
    SaveSetting("dirLockMode",    dirLockMode ? "1" : "0")

    gui.Destroy()

    if (showOverlay)
        CreateOverlay()
    else if (overlayGui != "")
        try overlayGui.Destroy()

    TrayTip("Settings saved", "Scroll Debouncer v3.5", 2)
}

; ── Direction tooltip ─────────────────────────────────────────

ShowDirectionTooltip() {
    global lockedDir
    label := lockedDir = "DOWN" ? "↓  SCROLL DOWN" : "↑  SCROLL UP"
    ToolTip(label)
    SetTimer(() => ToolTip(), -1200)
}

; ── Stats & exit ──────────────────────────────────────────────

ShowStats(*) {
    global sessionPhantoms, sessionEvents, sessionStart
    global cnCurrent, baseCN, dirLockMode, wornEncoderMode, wornSleepMs
    elapsed := Round((A_TickCount - sessionStart) / 1000)
    rate    := sessionEvents > 0 ? Round(sessionPhantoms / sessionEvents * 100, 1) : 0
    health  := rate < 5 ? "🟢 Good" : rate < 20 ? "🟡 Moderate wear" : "🔴 Heavy wear — replace encoder"
    mode    := dirLockMode ? "🔒 Direction Lock" : "● Normal (adaptive)"
    worn    := wornEncoderMode ? "ON (" . wornSleepMs . "ms)" : "OFF"
    MsgBox(
        "Scroll Debouncer v3.5 — Session Stats`n`n" .
        "Mode:             " . mode . "`n" .
        "Worn Encoder Mode: " . worn . "`n" .
        "Duration:         " . elapsed . "s`n" .
        "Events:           " . sessionEvents . "`n" .
        "Phantoms blocked: " . sessionPhantoms . "`n" .
        "Phantom rate:     " . rate . "%`n" .
        "Current CN:       " . cnCurrent . " (base=" . baseCN . ")`n`n" .
        "Encoder health:   " . health,
        "Scroll Debouncer v3.5"
    )
}

OnExit(SaveStats)
SaveStats(reason, code) {
    global sessionPhantoms, sessionEvents, sessionStart, dirLockMode, iniFile, wornEncoderMode
    statsFile := A_ScriptDir . "\scroll_stats.csv"
    elapsed   := Round((A_TickCount - sessionStart) / 1000)
    rate      := sessionEvents > 0 ? Round(sessionPhantoms / sessionEvents * 100, 2) : 0
    if !FileExist(statsFile)
        FileAppend("date,duration_s,events,phantoms,phantom_pct,mode,worn_mode`n", statsFile)
    FileAppend(
        FormatTime(, "yyyy-MM-dd HH:mm") . "," .
        elapsed . "," . sessionEvents . "," .
        sessionPhantoms . "," . rate . "," .
        (dirLockMode ? "lock" : "normal") . "," .
        (wornEncoderMode ? "on" : "off") . "`n",
        statsFile
    )
}
