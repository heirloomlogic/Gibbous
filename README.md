<div align="center">
    <img src=".github/Gibbous@2x.png" width="256" alt="Gibbous app icon">
</div>

# Gibbous

**A menu-bar moon companion for the Mac — and a working showcase of the Heirloom Logic stack.**

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform macOS 26.5+](https://img.shields.io/badge/platform-macOS%2026.5%2B-lightgrey.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)


Gibbous lives in your menu bar and shows the Moon — its phase, age, illumination, distance, and the dates of the surrounding new, quarter, and full moons — recomputed live, every second. Click the status‑bar glyph for the companion, and flip between a modern 2026 dashboard and a System‑7 retro window.

It is also three things at once:

- **A real, usable Mac app.** Dual skins, a Metal‑rendered Moon with real libration and limb darkening, and an optional full‑moon howl.
- **A working demo of the Heirloom Logic open‑source stack** — [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit) for the ephemeris, [Swidux](https://github.com/heirloomlogic/Swidux) for state, and [Persnicket](https://github.com/heirloomlogic/Persnicket) for lint/format. If you want to see these libraries used together in something that actually ships, this is the reference.
- **An homage to *Moontool*** — John Walker's 1988 original and Richard Knuckey's Macintosh *Moon Tool*.

## Download

Grab the latest signed and notarized build from the
[**Releases**](https://github.com/heirloomlogic/Gibbous/releases) page — download the
`.dmg`, open it, and drag Gibbous to your Applications folder. Or build it yourself
([Build & run](#build--run)).

## Features

- **Live menu‑bar glyph** — a tiny rendered Moon in the status item, updated on the clock.
- **Click for the companion** — left‑click the glyph for a popdown with the full readout; right‑click for a menu to switch skins, toggle phase sounds, or quit.
- **Two skins** — a modern dark dashboard, or a System‑7 retro window with the Chicago bitmap font and a 1‑bit dithered Moon.
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
    var displayStyle: DisplayStyle = .modern   // modern or retro
    var soundsEnabled: Bool = false            // the full-moon howl
    var readout: MoonReadout? = nil            // latest computed readout
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

**Requirements:** Xcode with the Swift 6 toolchain, macOS 26.5 or later, and [Git LFS](https://git-lfs.com) — the Moon textures, sounds, fonts, and app‑icon art are stored as Git LFS objects.

Install Git LFS *before* cloning so the binary assets download with the repo:

```sh
brew install git-lfs   # or see https://git-lfs.com
git lfs install        # once per machine
git clone https://github.com/heirloomlogic/Gibbous.git
cd Gibbous
open Gibbous.xcodeproj
```

Xcode resolves the Swift Package dependencies (AstronomyKit, Swidux, Persnicket) automatically on first open. Press **⌘R** to run.

> **Already cloned and the build fails with “Distill failed for unknown reasons” (or the Moon textures are missing)?** The binary assets are still Git LFS *pointer* files. Run `./Scripts/bootstrap.sh` to fix it, or do it by hand:
>
> ```sh
> brew install git-lfs   # or see https://git-lfs.com
> git lfs install
> git lfs pull
> ```

Gibbous launches as a menu‑bar accessory — there is no Dock icon and no main window. Look for the Moon glyph in the status bar; left‑click it for the companion, and right‑click for the menu to switch skins, toggle phase sounds, or quit.

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

## From Heirloom Logic

Gibbous is free, and it's a front door. The same engine and craft go into
[Heirloom Logic](https://heirloomlogic.com/)'s apps — two of them are the
Moon you're watching here, taken further:

- **Fallow** — a companion for lunar fasting, keeping a fast in time with the Moon.
- **Edict** — for choosing the right moment to act on a decision.

Both are built on AstronomyKit, like Gibbous. Coming from Heirloom Logic.

## Built with

- [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit) — Sun, Moon, planet, and star positions in Swift
- [Swidux](https://github.com/heirloomlogic/Swidux) — Redux‑style state management for SwiftUI
- [Persnicket](https://github.com/heirloomlogic/Persnicket) — a lightweight `swift-format` SPM plugin

## License

Gibbous is released under the MIT License, matching its sibling Heirloom Logic projects. _(A `LICENSE` file should be added to this repository.)_
