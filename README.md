# scroll-wheel-debouncer

A software-only fix for erratic mouse scroll wheel behavior caused by worn encoder hardware. No disassembly required. Built and tuned using real hardware data captured from faulty Logitech mice.

**Tested on:** Logitech G102, Logitech M150  
**Platform:** Windows (AutoHotkey v2)  
**Status:** Verified — 0 phantom flips reaching applications across 1,291 captured events

---

## The problem

Scroll wheel encoders wear out. When they do, the hardware fires garbage signals that no amount of driver reinstalling or software settings will fix:

- Random direction flips mid-scroll
- Multi-event phantom bursts (2–4 opposite-direction signals fired at once)
- 0ms simultaneous opposing events
- Inconsistent scroll sensitivity

This repo provides an AutoHotkey v2 script that intercepts scroll input system-wide and filters out the hardware noise before it reaches any application.

---

## Caps Lock triggering — separate issue

If you are also getting **accidental Caps Lock activations** while scrolling, that is **not the encoder** and this script does not need to account for it. The cause is **Logi Options+** (Logitech's companion software) interpreting rapid scroll bursts as a Caps Lock gesture. Fix: uninstall Logi Options+. The issue disappears immediately.

---

## How it works

Two filtering layers run in sequence on every scroll event:

### Layer 1 — time gate (`reverseBlockMs`)
After sending a scroll event, any opposite-direction event arriving within `reverseBlockMs` milliseconds is suppressed. Handles fast single-event phantom flips.

### Layer 2 — direction buffer (`consecutiveNeeded`)
A direction change is only confirmed and sent if the same new direction appears `consecutiveNeeded` times in a row. This catches slow multi-event phantom bursts that arrive too far apart to be caught by the time gate alone.

**Why both are needed:** worn encoders can fire phantom bursts with internal gaps of 200ms+. A time gate alone gets bypassed by these. The direction buffer catches them regardless of timing.

---

## Quick start

### Requirements
- Windows
- [AutoHotkey v2](https://www.autohotkey.com/download/)

### Installation
1. Download `scroll_fix_final.ahk`
2. Double-click to run — a tray icon confirms it's active
3. To auto-start on boot: press `Win+R`, type `shell:startup`, place a shortcut to the `.ahk` file there

---

## Files

| File | Description |
|---|---|
| `scroll_fix_final.ahk` | Main debouncer script — use this |
| `scroll_logger.ahk` | Captures raw scroll events to `scroll_log.txt` for tuning |

---

## scroll_fix_final.ahk

```autohotkey
; === Scroll Wheel Debouncer — FINAL ===
; Tuned across 4 rounds / 1291 live hardware events.
; Confirmed 0 phantom flips reaching applications.
;
; reverseBlockMs=200  covers worst observed phantom burst gap
; consecutiveNeeded=3 blocks all observed phantom bursts (max 4 events wide)
;                     Real direction changes always produce 5+ events.

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
```

---

## scroll_logger.ahk

Run this **without** the debouncer active to capture your raw hardware events. Scroll for ~30 seconds (mix of slow/fast, up/down), then check `scroll_log.txt` in the same folder.

```autohotkey
; === Scroll Event Logger ===
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
```

---

## Tuning for your mouse

The default values were derived from specific hardware. If the script doesn't fully fix your mouse, use the logger to capture your own data and adjust:

### Parameter guide

| Parameter | Default | What it does | When to increase | When to decrease |
|---|---|---|---|---|
| `reverseBlockMs` | 200 | Suppresses opposite-direction events within this window | Phantom flips still slip through | Direction changes feel slow to respond |
| `consecutiveNeeded` | 3 | Number of same-direction events required to confirm a change | Phantom bursts still getting through | Direction changes require too many scrolls to register |
| `wheelUpDelay` | 13 | Cooldown after each WheelUp event | Burst multi-scrolls upward | Upward scrolling feels sluggish |
| `wheelDownDelay` | 13 | Cooldown after each WheelDown event | Burst multi-scrolls downward | Downward scrolling feels sluggish |

### How to read your log

Look at rows where `direction_change = YES`:

- **Gap < 50ms** → almost certainly a phantom flip. Your `reverseBlockMs` should be higher than the largest gap in this group.
- **Multiple consecutive direction changes** → a multi-event burst. Count the longest burst and set `consecutiveNeeded` to that length + 1.
- **Gap 0ms** → hardware fired two signals at the same millisecond. Only the direction buffer can catch these.

### Finding the natural threshold

Sort the `gap_from_prev_ms` values for direction-change rows. Worn encoders typically show a clear bimodal distribution:

```
0–100ms:   dense cluster  ← phantom flips
100–150ms: near-empty     ← natural threshold lives here
150ms+:    activity       ← real intentional direction changes
```

Set `reverseBlockMs` to the midpoint of that empty valley.

---

## Results from hardware testing

| Session | Events | Raw phantoms | Phantoms reaching apps | Reduction |
|---|---|---|---|---|
| Baseline (no script) | 664 | 181 | 181 | — |
| v1 (time gate only, 125ms) | 162 | 75 | 2 | 98.9% |
| v2 (time gate + buffer n=2, 125ms) | 162 | 75 | 14 | 92.3% |
| v3 (time gate + buffer n=2, 200ms) | 696 | 54 | 15 | 91.7% |
| **Final (time gate + buffer n=3, 200ms)** | **696** | **54** | **0** | **100%** |

v2 introduced the buffer but `reverseBlockMs` was too low for some burst gaps. v3 raised it but `consecutiveNeeded=2` wasn't enough for 3–4 event bursts. The final version combines both fixes.

---

## Known limitations

- **AHK intercepts all mice globally** — you cannot apply different settings per mouse without separate AHK profiles
- **Very degraded encoders** — extremely worn hardware may produce bursts exceeding these thresholds. Raise `reverseBlockMs` and `consecutiveNeeded` accordingly and re-run the logger
- **Not a hardware fix** — the encoder is still worn. This filters the noise but as hardware degrades further, values may need re-tuning

---

## Contributing

If you tune this for a different mouse model and find values that work well, PRs and issues with the log data and final values are welcome. The more hardware profiles collected, the better the defaults can get.

---

## License

MIT
