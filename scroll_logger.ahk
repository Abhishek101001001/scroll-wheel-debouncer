; === Scroll Event Logger ===
; Run this WITHOUT the debouncer active to capture raw hardware events.
; Scroll for ~30 seconds (mix of slow/fast, up/down), then exit from tray.
; Output: scroll_log.txt in the same folder as this script.
;
; Use the log to tune reverseBlockMs and consecutiveNeeded in scroll_fix_final.ahk

logFile    := A_ScriptDir . "\scroll_log.txt"
lastTime   := 0
lastDir    := ""
eventCount := 0

if FileExist(logFile)
    FileDelete(logFile)
FileAppend("event,direction,timestamp_ms,gap_from_prev_ms,direction_change`n", logFile)

WheelUp:: {
    global lastTime, lastDir, eventCount, logFile
    now     := A_TickCount
    gap     := (lastTime = 0) ? 0 : (now - lastTime)
    changed := (lastDir = "DOWN") ? "YES" : "no"
    eventCount++
    FileAppend(eventCount . ",UP," . now . "," . gap . "," . changed . "`n", logFile)
    lastTime := now
    lastDir  := "UP"
    Send("{WheelUp}")
}

WheelDown:: {
    global lastTime, lastDir, eventCount, logFile
    now     := A_TickCount
    gap     := (lastTime = 0) ? 0 : (now - lastTime)
    changed := (lastDir = "UP") ? "YES" : "no"
    eventCount++
    FileAppend(eventCount . ",DOWN," . now . "," . gap . "," . changed . "`n", logFile)
    lastTime := now
    lastDir  := "DOWN"
    Send("{WheelDown}")
}
