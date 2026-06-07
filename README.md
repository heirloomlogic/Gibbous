<div align="center">
    <img src=".github/Gibbous@2x.png" width="256" alt="Gibbous app icon">
</div>

# Gibbous

**A tear-off moon companion for the Mac — and a working showcase of the Heirloom Logic stack.**

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform macOS 26.5+](https://img.shields.io/badge/platform-macOS%2026.5%2B-lightgrey.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)


Gibbous lives in your menu bar and shows the Moon — its phase, age, illumination, distance, and the dates of the surrounding new, quarter, and full moons — recomputed live, every second. Tear it off into a floating desktop panel, flip between a modern 2026 dashboard and a System‑7 retro window, or shrink it down to just the disc as a quiet desktop pet.

It is also three things at once:

- **A real, usable Mac app.** Dual skins, a tear‑off floating panel, a Metal‑rendered Moon with real libration and limb darkening, and an optional full‑moon howl.
- **A working demo of the Heirloom Logic open‑source stack** — [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit) for the ephemeris, [Swidux](https://github.com/heirloomlogic/Swidux) for state, and [Persnicket](https://github.com/heirloomlogic/Persnicket) for lint/format. If you want to see these libraries used together in something that actually ships, this is the reference.
- **An homage to *Moontool*** — John Walker's 1988 original and Richard Knuckey's Macintosh *Moon Tool*.

## Features

- **Live menu‑bar glyph** — a tiny rendered Moon in the status item, updated on the clock.
- **Two skins** — a modern dark dashboard, or a System‑7 retro window with the Chicago bitmap font and a 1‑bit dithered Moon.
- **Two densities** — full stats readout, or moon‑only as a minimal desktop companion.
- **Tear‑off floating panel** — detach from the menu bar into a movable, resizable desktop window, with an optional always‑on‑top mode. Position is remembered between launches.
- **Metal‑rendered Moon** — a sphere‑impostor shader with phase terminator, limb darkening, libration tilt, and tangent‑space normal mapping for crater relief, from 8K albedo and normal maps.
- **Full‑moon howl** — an optional sound as the clock crosses the full moon (off by default).
- **Accurate ephemeris** — phase, libration, and phase‑event dates from AstronomyKit, validated against a golden master.

## What it showcases

### AstronomyKit — the ephemeris

All of the Moon math comes from [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit). The pure data layer in [`Gibbous/Model/MoonAlmanac.swift`](Gibbous/Model/MoonAlmanac.swift) takes one instant and returns one `MoonReadout`:

```swift
import AstronomyKit

let t = AstroTime(date)

let phaseAngle = try Moon.phaseAngle(at: t)
let libration = Moon.libration(at: t)
let sun = try Sun.position(at: t)

// The phase events of the lunation — the expensive part, computed once
// per lunation and reused across clock ticks.
let lastNew = try Moon.searchPhase(.new, after: t.addingDays(-45))
let firstQuarter = try Moon.searchPhase(.firstQuarter, after: lastNew)
let fullMoon = try Moon.searchPhase(.full, after: lastNew)
let nextNew = try Moon.searchPhase(.new, after: lastNew.addingDays(1))
```

Because Gibbous knows the iconic 2014‑10‑05 *Moon Tool* screenshot, its accuracy is pinned to that frame as a golden‑master test in [`GibbousTests/MoonAlmanacGoldenTests.swift`](GibbousTests/MoonAlmanacGoldenTests.swift).

### Swidux — the state

Gibbous is deliberately small, which makes it a clean read of the [Swidux](https://github.com/heirloomlogic/Swidux) pattern: a single `@Swidux` state ([`Gibbous/App/AppState.swift`](Gibbous/App/AppState.swift)), a pure synchronous reducer, and effects that capture only the environment — never mutable state.

```swift
@Swidux
nonisolated struct AppState: Equatable, Sendable {
    var displayStyle: DisplayStyle = .modern
    var density: Density = .stats
    var presentation: Presentation = .menuBarPopdown
    var readout: MoonReadout? = nil
}
```

The reducer in [`Gibbous/App/AppReducer.swift`](Gibbous/App/AppReducer.swift) mutates in place and hands back effects — the once‑a‑second clock loop, the off‑main ephemeris compute, persisting a preference — each returned as a closure over `environment`:

```swift
case .tick(let date):
    return computeReadout(for: date, reusing: reuse)

case .setDisplayStyle(let value):
    state.displayStyle = value
    return persist(value, for: .displayStyle)
```

Scalar preferences are persisted through Swidux's `KeyValueStore`; everything else is ephemeral session state. No entities, no SwiftData, no domain plugins — just store, reducer, and effects.

### Persnicket — the lint/format

Both targets attach [Persnicket](https://github.com/heirloomlogic/Persnicket)'s `Persnoop` build‑tool plugin, so every build lints and formats the source with `swift-format`. There's nothing to run by hand — open the project and build.

## Build & run

**Requirements:** Xcode with the Swift 6 toolchain, macOS 26.5 or later.

```sh
git clone https://github.com/heirloomlogic/Gibbous.git
cd Gibbous
open Gibbous.xcodeproj
```

Xcode resolves the Swift Package dependencies (AstronomyKit, Swidux, Persnicket) automatically on first open. Press **⌘R** to run.

Gibbous launches as a menu‑bar accessory — there is no Dock icon and no main window. Look for the Moon glyph in the status bar; click it for the companion, and press **⌘,** for Settings.

## Tests

Run the suite with **⌘U** in Xcode, or from the command line:

```sh
xcodebuild test -scheme Gibbous -destination 'platform=macOS'
```

Tests use the Swift `Testing` framework. The render and snapshot tests draw the Moon with Metal, so they need a machine with a GPU.

## Heritage

A homage to *Moontool* by John Walker (1988) and the Macintosh *Moon Tool* by Richard Knuckey. Built on AstronomyKit. Gibbous reimplements the idea with its own code and art — it borrows the spirit, not the source.

- [Moontool for Unix/Windows](https://www.fourmilab.ch/moontool/) — John Walker, Fourmilab
- [Moon Tool 1.0.1 for Macintosh](https://www.macintoshrepository.org/150-moon-tool-1-0-1) — Macintosh Repository

## Built with

- [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit) — Sun, Moon, planet, and star positions in Swift
- [Swidux](https://github.com/heirloomlogic/Swidux) — Redux‑style state management for SwiftUI
- [Persnicket](https://github.com/heirloomlogic/Persnicket) — a lightweight `swift-format` SPM plugin

## License

Gibbous is released under the MIT License, matching its sibling Heirloom Logic projects. _(A `LICENSE` file should be added to this repository.)_
