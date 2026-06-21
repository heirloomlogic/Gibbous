# Contributing to Gibbous

Gibbous is a tear-off Moon companion for the Mac, and a working showcase of the open-source [Heirloom Logic](https://heirloomlogic.com) stack — [AstronomyKit](https://github.com/heirloomlogic/AstronomyKit), [Swidux](https://github.com/heirloomlogic/Swidux), and [Persnicket](https://github.com/heirloomlogic/Persnicket). Contributions that improve the app, or make it a clearer reference for those libraries, are welcome.

## Reporting Bugs

Open a [bug report](https://github.com/heirloomlogic/Gibbous/issues/new?template=bug_report.md) with:

- The Gibbous and macOS versions you are using
- Which skin and density you were in (modern / retro, stats / moon-only)
- Steps to reproduce
- Expected vs. actual behavior

## Prerequisites

Gibbous stores its binary assets — the Moon textures, sounds, fonts, and app‑icon art — with [Git LFS](https://git-lfs.com). Install it **before** cloning so the assets come down with the repo:

```sh
brew install git-lfs   # or see https://git-lfs.com
git lfs install        # once per machine
```

Already cloned and seeing **“Distill failed for unknown reasons”** or missing textures at build time? The assets are still Git LFS pointer files — run `./Scripts/bootstrap.sh`, or install Git LFS as above and run `git lfs pull`.

## Submitting Changes

1. Fork the repository and create a branch from `main`.
2. Open `Gibbous.xcodeproj` in Xcode. The Swift Package dependencies (AstronomyKit, Swidux, Persnicket) resolve automatically on first open.
3. Make your changes.
4. Build (**⌘B**). Persnicket lints and formats the source on every build (see [Code Style](#code-style)); resolve any warnings.
5. Run the tests (**⌘U**, or `xcodebuild test -scheme Gibbous -destination 'platform=macOS'`) and confirm they pass.
6. Open a pull request describing what you changed and why.

### Code Style

The project uses [swift-format](https://github.com/swiftlang/swift-format) via [Persnicket](https://github.com/heirloomlogic/Persnicket)'s `Persnoop` build-tool plugin, attached to both targets. Linting and formatting run automatically during the build — there is nothing to run by hand. Resolve all lint warnings before submitting a PR.

### Tests

New functionality should include tests. Bug fixes should include a test that would have caught the issue. Tests use the Swift [`Testing`](https://developer.apple.com/documentation/testing) framework. The render and snapshot tests draw the Moon with Metal, so they need a machine with a GPU.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](.github/CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Questions

If you have questions that aren't covered here, open an issue or email gibbous@heirloomlogic.com.
