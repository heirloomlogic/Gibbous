# Security Policy

## Supported Versions

Security fixes are applied to the latest released version of Gibbous. Older versions are not maintained.

## Reporting a Vulnerability

If you believe you have found a security issue in Gibbous, please **do not** open a public GitHub issue. Instead, email gibbous@heirloomlogic.com with:

- A description of the issue and its impact
- Steps to reproduce
- Any suggested remediation

You can expect an acknowledgement within a few business days. Once the issue is confirmed, we will coordinate a fix and a disclosure timeline with you.

## Scope

Gibbous is an on-device macOS menu-bar app. It performs no network I/O, has no account or backend, and processes no untrusted input — it persists only scalar preferences locally through Swidux's `KeyValueStore`. Plausible issues include:

- Memory-safety bugs in the Metal render path (`MoonRenderer` and the `Moon.metal` shader)
- Malformed persisted preferences that cause crashes or undefined behavior on launch

Reports on cosmetic issues, UX behavior, or defects in the upstream Heirloom Logic packages (AstronomyKit, Swidux, Persnicket) unrelated to Gibbous itself should be filed as regular GitHub issues, or in the relevant package's repository.
