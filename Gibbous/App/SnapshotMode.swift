//
//  SnapshotMode.swift
//  Gibbous
//
//  Debug-only screenshot harness. When the app is launched in snapshot mode the
//  clock is frozen at a hand-picked waxing-gibbous instant, so every App Store /
//  marketing capture shares one consistent moment in time — open the popover,
//  flip skins, toggle light/dark, and the Moon never moves between shots.
//
//  Activated entirely through the process environment (see Scripts/snapshot.sh),
//  so it adds no UI and no production code path:
//    GIBBOUS_SNAPSHOT=1            turn snapshot mode on
//    GIBBOUS_SNAPSHOT_DATE=<ISO>   optional override of the frozen instant
//
//  The whole feature is compiled out of Release builds.
//

#if DEBUG
import Foundation

/// Reads the snapshot-mode flags from the process environment and, when active,
/// freezes `AppEnvironment.now` at a fixed instant. Parsing is split out behind
/// an injectable environment dictionary so it can be unit-tested without
/// touching the real process environment.
nonisolated enum SnapshotMode {
    private static let activationKey = "GIBBOUS_SNAPSHOT"
    private static let dateKey = "GIBBOUS_SNAPSHOT_DATE"

    /// Whether this process was launched in snapshot mode.
    static func isActive(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        env[activationKey] == "1"
    }

    /// The instant the clock is frozen at: the ISO-8601 `GIBBOUS_SNAPSHOT_DATE`
    /// override when present and parseable, otherwise the curated default.
    static func lockedDate(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Date {
        if let raw = env[dateKey], let parsed = ISO8601DateFormatter().date(from: raw) {
            return parsed
        }
        return defaultDate
    }

    /// A curated waxing-gibbous moment — 2025-09-04T03:00:00Z, ~3½ days before
    /// the 2025-09-07 full moon (~80% illuminated). Pinned to the
    /// `.waxingGibbous` requirement by `SnapshotModeTests`.
    static let defaultDate = Date(timeIntervalSince1970: 1_756_954_800)

    /// `base` unchanged when snapshot mode is off; otherwise a copy with `now`
    /// frozen at `lockedDate`. Everything downstream — the readout, the glyph,
    /// the footer date/time — follows from that single seam.
    static func environment(
        _ base: AppEnvironment,
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppEnvironment {
        guard isActive(env) else { return base }
        let frozen = lockedDate(env)
        var snapshot = base
        snapshot.now = { frozen }
        return snapshot
    }
}
#endif
