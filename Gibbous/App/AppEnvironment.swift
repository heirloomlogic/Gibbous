//
//  AppEnvironment.swift
//  Gibbous
//
//  Injected dependencies for effects. Everything the reducer's async work
//  touches — preferences, the clock, ephemeris, the charm cue — comes through
//  here, so tests can substitute in-memory/stub implementations.
//

import AppKit
import Foundation

nonisolated struct AppEnvironment: Sendable {
    var keyValue: any KeyValueStore
    var timeZone: TimeZone
    /// Current wall-clock instant (injectable for tests).
    var now: @Sendable () -> Date
    /// Compute a readout for an instant; throws → "unavailable". When the
    /// instant is still in the same lunation, the caller passes the previous
    /// readout's events to reuse instead of re-running the phase searches.
    var computeReadout: @Sendable (Date, TimeZone, LunationEvents?) throws -> MoonReadout
    /// Fire the flagship full-moon cue. Wired by the shell; no-op until then.
    var playHowl: @Sendable () -> Void

    static func live() -> AppEnvironment {
        AppEnvironment(
            keyValue: UserDefaultsKeyValueStore(),
            timeZone: .current,
            now: { Date() },
            computeReadout: { date, timeZone, reuse in
                let events = try reuse ?? MoonAlmanac.lunationEvents(containing: date)
                return try MoonAlmanac.readout(at: date, timeZone: timeZone, events: events)
            },
            playHowl: {
                // Plays the bundled, licensed howl from Resources/Sounds.
                // Gracefully no-ops if the asset can't be found or decoded.
                Task { @MainActor in
                    guard
                        let url = Bundle.main.url(forResource: "howl", withExtension: "m4a"),
                        let sound = NSSound(contentsOf: url, byReference: true)
                    else { return }
                    sound.play()
                }
            }
        )
    }
}
