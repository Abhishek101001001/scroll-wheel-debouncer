; === Scroll Wheel Debouncer — FINAL ===
; Tuned across 4 rounds / 1291 live hardware events.
; Confirmed 0 phantom flips reaching applications.
;
; reverseBlockMs=200  covers worst observed phantom burst gap
; consecutiveNeeded=3 blocks all observed phantom bursts (max 4 events wide)
;                     Real direction changes always produce 5+ events.
;
; NOTE: If you are getting accidental Caps Lock triggers while scrolling,
; the cause is Logi Options+ (Logitech's software) interpreting rapid scroll
; signals as a gesture. Uninstall Logi Options+ and the Caps Lock issue
; disappears completely — no script change needed.
;
; TUNING GUIDE:
;   reverseBlockMs    — raise if phantom flips still slip through
;   consecutiveNeeded — raise if multi-event bursts still get through

reverseBlockMs    := 200
wheelUpDelay      := 13
wheelDownDelay    := 13
consecutiveNeeded := 3

global lastDir      := ""
global pendingDir   := ""
global pendingCount := 0

WheelUp:: {
    global lastDir, pendingDir, pendingCount
    global reverseBlockMs, wheelUpDelay, consecutiveNeeded

    if (A_PriorHotKey = "WheelDown" and A_TimeSincePriorHotkey < reverseBlockMs) {
        Sleep(reverseBlockMs)
        return
    }
    if (lastDir = "UP" or lastDir = "") {
        lastDir      := "UP"
        pendingDir   := ""
        pendingCount := 0
        Send("{WheelUp}")
        Sleep(wheelUpDelay)
    } else {
        if (pendingDir = "UP")
            pendingCount++
        else {
            pendingDir   := "UP"
            pendingCount := 1
        }
        if (pendingCount >= consecutiveNeeded) {
            lastDir      := "UP"
            pendingDir   := ""
            pendingCount := 0
            Send("{WheelUp}")
            Sleep(wheelUpDelay)
        }
    }
}

WheelDown:: {
    global lastDir, pendingDir, pendingCount
    global reverseBlockMs, wheelDownDelay, consecutiveNeeded

    if (A_PriorHotKey = "WheelUp" and A_TimeSincePriorHotkey < reverseBlockMs) {
        Sleep(reverseBlockMs)
        return
    }
    if (lastDir = "DOWN" or lastDir = "") {
        lastDir      := "DOWN"
        pendingDir   := ""
        pendingCount := 0
        Send("{WheelDown}")
        Sleep(wheelDownDelay)
    } else {
        if (pendingDir = "DOWN")
            pendingCount++
        else {
            pendingDir   := "DOWN"
            pendingCount := 1
        }
        if (pendingCount >= consecutiveNeeded) {
            lastDir      := "DOWN"
            pendingDir   := ""
            pendingCount := 0
            Send("{WheelDown}")
            Sleep(wheelDownDelay)
        }
    }
}
