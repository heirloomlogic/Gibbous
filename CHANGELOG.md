# Changelog

All notable changes to Gibbous will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial public release of Gibbous, a tear-off Moon companion for the Mac.
- Live menu-bar glyph with a rendered Moon, updated on the clock.
- Two skins: a modern dark dashboard and a System-7 retro window with the Chicago bitmap font and a 1-bit dithered Moon.
- Two densities: full stats readout and moon-only.
- Tear-off floating panel with optional always-on-top mode and remembered position.
- Metal-rendered Moon: sphere-impostor shader with phase terminator, limb darkening, libration tilt, and tangent-space normal mapping from 8K albedo and normal maps.
- Optional phase charm cues, off by default: a wolf howl as the clock crosses the full moon and an owl hoot as it crosses the new moon.
- Accurate ephemeris — phase, libration, and phase-event dates from [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit), validated against a golden master.
- State management via [Swidux](https://github.com/heirloomlogic/Swidux); lint/format via [Persnicket](https://github.com/heirloomlogic/Persnicket).
