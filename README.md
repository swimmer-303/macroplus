# MacroPlus

A fast, native **autoclicker & macro studio** for macOS — built in Swift + SwiftUI.

![MacroPlus icon](Resources/MacroPlus.iconset/icon_256x256.png)

## Features

### 🖱 Autoclicker
- Precise click interval down to the millisecond (hours / minutes / seconds / ms).
- Live **clicks-per-second** readout and one-tap presets (10 / 25 / 50 / 100 CPS).
- Left, right, or middle button · single or double click.
- Repeat **until stopped** or an exact **number of clicks**.
- Click at the **current cursor** or a **fixed point** (with a "capture cursor" picker).
- **Humanize** mode adds subtle random timing & position jitter.
- Global **start/stop hotkey** (default `F6`, rebindable).

### ⏺ Macro recorder
- Record real mouse clicks, movement, scrolling and keystrokes **system-wide**.
- Replay any macro with a **repeat count** and **0.25×–4× speed** control.
- Step-by-step inspector showing every captured event and its timing.
- Macros are saved to disk and **import/export** as JSON.

### ✨ Polish
- Clean SwiftUI interface with a sidebar, status bar and live indicators.
- Lives in the **menu bar** for quick start/stop without opening the window.
- Keyboard shortcuts: `⌘R` start/stop · `⌘E` record · `⌘P` play.

## Build & run

```bash
./build.sh           # compiles, makes the icon, assembles MacroPlus.app
open MacroPlus.app
```

Or for development:

```bash
swift build
swift run
```

### Requirements
- macOS 13+
- Xcode command-line tools / Swift 5.9+

## Permissions

MacroPlus uses synthetic input events, so macOS requires **Accessibility** access:

> System Settings → Privacy & Security → Accessibility → enable **MacroPlus**

The app prompts you automatically the first time you start a click or recording.
The in-app badge shows the current permission status and links straight to the setting.

## Project layout

```
Sources/MacroPlus/
  Models.swift          data types (clicks, macros, intervals)
  AutoClicker.swift     high-precision click engine
  MacroEngine.swift     record + playback engine
  HotkeyManager.swift   global start/stop hotkey
  MacroStore.swift      JSON persistence
  Permissions.swift     Accessibility handling
  AppState.swift        shared state
  MacroPlusApp.swift    app entry + menu bar
  Views/                SwiftUI interface
tools/generate_icon.swift   procedural app-icon renderer
build.sh                    bundles & signs MacroPlus.app
```

## Notes
Use responsibly and only in software where automation is permitted.
