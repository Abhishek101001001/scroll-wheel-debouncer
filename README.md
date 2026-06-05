# Scroll Wheel Debouncer

A software-only fix for erratic mouse scroll wheel behavior caused by worn encoder hardware. No disassembly required. Built and tuned using real hardware data captured from faulty Logitech mice.

**Tested on:** Logitech G102, Logitech M150
**Platform:** Windows (AutoHotkey v2)
**Status:** v3.4 — fully working, 0 phantom flips on healthy encoders, Direction Lock mode for heavily worn encoders

---

## ⬇️ Download

| Version | File | Best for |
|---------|------|----------|
| **v3.5.1 (latest)** | [`scroll_fix_v3.ahk`](./scroll_fix_v3.ahk) | Everyone — use this |
| v1 (original) | [`scroll_fix_final.ahk`](./scroll_fix_final.ahk) | Simple, no UI, works too |

---

## What's new in v3.4

- **Worn Encoder Sleep Mode** (`Ctrl+Alt+W`) — adds a configurable sleep only in the phantom-discard branch, giving heavily worn encoders the hard dead zone that v1's `Sleep(200ms)` approach provided, without slowing down good scroll events
- **Direction Lock Mode** — middle-click cycles UP / DOWN / OFF; turns a nearly dead encoder into a usable mouse
- **Adaptive backoff CN** — self-tightening/relaxing filter, no `Sleep()` in the forward-scroll path
- **Persistent overlay** — top-right corner shows current mode at all times
- **Auto-detect encoder health** — first 60 seconds measures phantom rate and suggests best mode
- **Per-app direction memory** — remembers your preferred scroll direction per application
- **Custom hotkey picker** — change any hotkey from Settings GUI
- **Colour-coded tray icon** — green (healthy) / yellow (moderate wear) / orange (worn mode on) / red (heavy wear)
- **Session stats** — phantom rate, encoder health rating, saved to CSV on exit
- **Bug fix:** Moved WheelUp/WheelDown hotkey blocks before function definitions — fixes AHK v2 "Hotkeys not allowed inside functions" crash

---

## The problem

Scroll wheel encoders wear out. When they do, the hardware fires garbage signals that no driver reinstall or software setting will fix:

- Random direction flips mid-scroll
- Multi-event phantom bursts (2–4 opposite-direction signals at once)
- 0ms simultaneous opposing events
- Inconsistent scroll sensitivity

This script intercepts scroll input system-wide and filters out the hardware noise before it reaches any application.

---

## Quick start

### Requirements

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/download/)

### Installation

1. Download `scroll_fix_v3.ahk`
2. Double-click to run — a tray icon confirms it's active
3. To auto-start on boot: press `Win+R`, type `shell:startup`, place a shortcut to the `.ahk` file there

### Hotkeys

| Hotkey | Action |
|--------|--------|
| `Middle Click` | Toggle direction (in Lock mode) / hold for free scroll |
| `Ctrl+Alt+W` | Toggle Worn Encoder Mode on/off |
| `Ctrl+Alt+S` | Toggle script on/off |
| `Ctrl+Alt+O` | Toggle overlay |

---

## Which mode should I use?

| Encoder condition | Recommended mode |
|-------------------|-----------------|
| Healthy / light wear | Normal mode, Worn Mode OFF |
| Moderate wear | Normal mode, Worn Mode ON (`Ctrl+Alt+W`), `wornSleepMs=130` |
| Heavy wear / barely usable | Direction Lock Mode (middle-click to toggle) |
| Dead encoder | Direction Lock — software can't fix fully dead hardware, replace the EC11 encoder (₹30–50) |

---

## How it works

### Layer 1 — time gate (`reverseBlockMs`)

After sending a scroll event, any opposite-direction event arriving within `reverseBlockMs` milliseconds is suppressed. Handles fast single-event phantom flips.

### Layer 2 — direction buffer (`consecutiveNeeded` / CN)

A direction change is only confirmed if the same new direction appears `CN` times in a row. Catches slow multi-event phantom bursts that arrive too far apart for the time gate alone.

### Layer 3 (v3.4) — Worn Encoder Sleep

When Worn Encoder Mode is ON, a short `Sleep(wornSleepMs)` fires after discarding a phantom — creating a hard blocking window that catches medium-gap phantoms (110–200ms) that the timestamp approach misses. Sleep is **only** in the discard branch, never in the forward-scroll branch.

---

## Tuning parameters

| Parameter | Default | What it does |
|-----------|---------|--------------|
| `reverseBlockMs` | 110 | Suppress opposite-direction events within this window (ms) |
| `baseCN` | 2 | Starting consecutive-events threshold |
| `maxCN` | 3 | Maximum CN (ceiling for adaptive backoff) |
| `wornSleepMs` | 130 | Sleep duration in discard branch when Worn Mode is ON (100–200ms) |

To edit: open the `.ahk` file in any text editor, change values at the top, save and re-run.

---

## Algorithm evolution

| Version | Approach | Phantom reduction |
|---------|----------|-------------------|
| v1 | Time gate only (125ms) | 98.9% |
| v2 | Time gate + `Sleep(200ms)` in discard branch | 100% on test data, 200ms sluggishness |
| v3 | Adaptive backoff CN, no Sleep() in hooks | ~99% on healthy encoder |
| v3.1 | + `pendingCN` locked at `baseCN` — fixes direction-change stutter | — |
| v3.2 | + Direction Lock Mode | Best option for dead encoders |
| v3.3 | + Auto-detect, overlay, per-app memory, hotkey picker | — |
| **v3.4** | **+ Worn Encoder Sleep Mode, AHK v2 hotkey crash fix** | **100% configurable** |

---

## Results from hardware testing

| Session | Events | Raw phantoms | Phantoms reaching apps | Reduction |
|---------|--------|-------------|----------------------|-----------|
| Baseline (no script) | 664 | 181 | 181 | — |
| v1 (time gate 125ms) | 162 | 75 | 2 | 98.9% |
| v2 (time gate + buffer, 125ms) | 162 | 75 | 14 | 92.3% |
| v3 (time gate + buffer, 200ms) | 696 | 54 | 15 | 91.7% |
| v1 final (n=3, 200ms) | 696 | 54 | 0 | 100% |
| **v3.4 normal mode (G102)** | — | — | **0** | **100%** |
| **v3.4 worn mode (M150)** | — | — | **0** | **100%** |

---

## Files

| File | Description |
|------|-------------|
| `scroll_fix_v3.ahk` | Main script v3.4 — use this |
| `scroll_fix_final.ahk` | Original v1 — simple, no UI |
| `scroll_logger.ahk` | Raw event capture tool for tuning |

---

## Hardware note

If your encoder is truly dead, software can only do so much. The EC11 encoder used in most Logitech mice costs ₹30–50 (~$0.50) and is a straightforward soldering job. Search "EC11 24-pulse encoder replacement" for guides.

---

## Contributing

If you tune this for a different mouse model and find values that work well, PRs and issues with log data and final values are welcome.

---

## License

MIT
