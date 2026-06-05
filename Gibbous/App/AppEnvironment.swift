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
    /// Compute a readout for an instant; throws → "unavailable".
    var computeReadout: @Sendable (Date, TimeZone) throws -> MoonReadout
    /// Fire the flagship full-moon cue. Wired by the shell; no-op until then.
    var playHowl: @Sendable () -> Void

    static func live() -> AppEnvironment {
        AppEnvironment(
            keyValue: UserDefaultsKeyValueStore(),
            timeZone: .current,
            now: { Date() },
            computeReadout: { try MoonAlmanac.readout(at: $0, timeZone: $1) },
            playHowl: {
                // Bundled, licensed audio only. No-ops until a howl file is
                // added to Resources/Sounds (see the build checklist).
                Task { @MainActor in
                    let bundle = Bundle.main
                    let url = bundle.url(forResource: "howl", withExtension: "wav")
                        ?? bundle.url(forResource: "howl", withExtension: "aiff")
                        ?? bundle.url(forResource: "howl", withExtension: "m4a")
                    if let url, let sound = NSSound(contentsOf: url, byReference: true) {
                        sound.play()
                    }
                }
            }
        )
    }
}
