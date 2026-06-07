# Scroll Wheel Debouncer

A software-only fix for erratic/bouncing Logitech scroll wheel behavior caused by worn encoder hardware. No disassembly required. Built and tuned using real hardware data captured from faulty Logitech mice.

**Tested on:** Logitech G102, Logitech M150  
**Platform:** Windows (AutoHotkey v2)  
**Latest:** v3.6

---

## Download

| Version | File | Notes |
|---------|------|-------|
| **v3.6 (latest)** | [`scroll_fix_v3.ahk`](./scroll_fix_v3.ahk) | Use this |
| v1 (original) | [`scroll_fix_final.ahk`](./scroll_fix_final.ahk) | Simple, no UI |

---

## Quick start

### Requirements
- Windows
- [AutoHotkey v2](https://www.autohotkey.com/download/)

### Installation
1. Download `scroll_fix_v3.ahk`
2. Double-click to run — tray icon confirms it's active
3. Auto-start on boot: press `Win+R` → type `shell:startup` → place a shortcut to the `.ahk` file there

---

## The problem

Scroll wheel encoders wear out. When they do, the hardware fires garbage signals that no driver reinstall or software setting will fix:

- Random direction flips mid-scroll
- Multi-event phantom bursts (2–4 opposite-direction signals at once)
- 0ms simultaneous opposing events
- Inconsistent scroll sensitivity

This script intercepts scroll input system-wide and filters out the hardware noise before it reaches any application.

---

## Features

### Normal Mode (default)
Adaptive phantom filtering — self-tightening/relaxing based on how many phantoms your encoder is firing. Works silently in the background. Best for healthy or lightly worn encoders.

### Direction Lock Mode
For heavily worn encoders that can't be reliably fixed by filtering alone.

- Locks scroll to **one direction only**
- **Tap** the toggle button → flip locked direction (UP ↔ DOWN)
- **Hold** the toggle button → free scroll in both directions while held, lock resumes on release
- Enable from tray icon → Direction Lock Mode

### Worn Encoder Sleep Mode
Press `Ctrl+Alt+W` to toggle. Adds a configurable sleep only in the phantom-discard branch — gives heavily worn encoders the hard dead zone that the original v1 approach had, without slowing down good scroll events.

Default sleep: 130ms. Range: 100–200ms (200ms = v1 behaviour).

---

## Hotkeys

| Hotkey | Action |
|--------|--------|
| Middle Click (tap) | Flip locked direction (Direction Lock mode only) |
| Middle Click (hold) | Free scroll while held (Direction Lock mode only) |
| `Ctrl+Alt+W` | Toggle Worn Encoder Mode on/off |

Toggle hotkey is fully customizable from Settings.

---

## Settings

Right-click tray icon → **⚙ Settings**

| Setting | Default | Description |
|---------|---------|-------------|
| Toggle hotkey | MButton | Button for direction flip / free scroll |
| Double-tap ms | 300 | Double-tap scroll speed to flip direction |
| Idle auto-reset | 0 (off) | Reset direction after N seconds idle |
| Worn encoder sleep | 130ms | Sleep duration in discard branch |
| Show overlay | ON | Top-right corner mode indicator |
| Show tooltips | ON | Cursor tooltip on direction flip / free scroll |
| Auto-detect health | ON | Measure phantom rate for 60s on startup |
| Default direction | DOWN | Direction on startup / idle reset |

All settings persist across reboots.

---

## Overlay

A small indicator sits in the top-right corner showing current mode:

| Display | Meaning |
|---------|---------|
| `● NORMAL` | Normal adaptive mode |
| `↓ DOWN` | Direction Lock — locked to scroll down |
| `↑ UP` | Direction Lock — locked to scroll up |
| `● NORMAL [WORN]` | Normal mode + Worn Encoder Mode on |

---

## Which mode should I use?

| Encoder condition | Recommended |
|-------------------|-------------|
| Healthy / light wear | Normal mode |
| Moderate wear | Normal mode + Worn Encoder Mode (`Ctrl+Alt+W`) |
| Heavy wear | Direction Lock Mode |
| Nearly dead | Direction Lock + consider replacing the EC11 encoder (₹30–50) |

---

## How it works

### Layer 1 — Time gate (`reverseBlockMs`)
After sending a scroll event, any opposite-direction event arriving within `reverseBlockMs` milliseconds is suppressed. Catches fast single-event phantom flips.

### Layer 2 — Direction buffer (adaptive CN)
A direction change is only confirmed if the same new direction appears `CN` times in a row. CN self-adjusts — tightens when phantoms are detected, relaxes when scrolling is clean. Catches slow multi-event phantom bursts that arrive too far apart for the time gate alone.

### Layer 3 — Worn Encoder Sleep (optional)
When Worn Encoder Mode is ON, a short `Sleep()` fires after discarding a phantom — creating a hard blocking window that catches medium-gap phantoms (110–200ms). Sleep is only in the discard branch, never in the forward-scroll branch.

---

## Tuning parameters

Edit at the top of `scroll_fix_v3.ahk`:

| Parameter | Default | What it does |
|-----------|---------|--------------|
| `reverseBlockMs` | 110 | Suppress opposite-direction events within this window (ms) |
| `baseCN` | 2 | Starting consecutive-events threshold |
| `maxCN` | 3 | Maximum CN ceiling |
| `wornSleepMs` | 130 | Sleep in discard branch when Worn Mode is ON (100–200ms) |

---

## Algorithm history

| Version | What changed | Phantom reduction |
|---------|-------------|-------------------|
| v1 | Time gate only (200ms) + Sleep in hook | 100% on test data, sluggish |
| v3.0 | Adaptive CN, no Sleep in forward path | ~99% healthy encoder |
| v3.1 | pendingCN fix — no direction-change stutter | — |
| v3.2 | Direction Lock Mode | Best for dead encoders |
| v3.3 | Auto-detect, overlay, per-app memory, hotkey picker | — |
| v3.4 | Worn Encoder Sleep Mode, AHK v2 crash fix | 100% configurable |
| v3.5 | Settings persistence, direction lock blocking fix | — |
| **v3.6** | **Tooltip control, free-scroll hold fix, full direction lock rewrite** | — |

---

## Results from hardware testing

| Session | Events | Phantoms blocked | Reduction |
|---------|--------|-----------------|-----------|
| Baseline (no script) | 664 | 0 | — |
| v1 final (200ms gate + buffer) | 696 | 100% | 100% |
| v3.6 Normal mode (G102) | — | 100% | 100% |
| v3.6 Direction Lock (M150) | — | 100% | 100% |

---

## Files

| File | Description |
|------|-------------|
| `scroll_fix_v3.ahk` | Main script v3.6 — use this |
| `scroll_fix_final.ahk` | Original v1 — simple, no UI |
| `scroll_logger.ahk` | Raw event capture tool for tuning |

---

## Hardware note

If your encoder is truly dead, software can only do so much. The EC11 encoder inside most Logitech mice costs ₹30–50 (~$0.50) and is a 20-minute soldering job. Search "EC11 24-pulse encoder replacement logitech" for guides.

---

## Contributing

If you tune this for a different mouse model and find values that work well, PRs and issues with log data and final values are welcome.

---

## License

MIT
