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
import ServiceManagement
import os

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
    /// Fire the new-moon cue. Wired by the shell; no-op until then.
    var playHoot: @Sendable () -> Void
    /// Register/unregister the app as a macOS login item. Best-effort; the
    /// reducer re-reads `loginItemEnabled` afterward so state reflects reality.
    var setLoginItemEnabled: @Sendable (Bool) -> Void
    /// Whether the app is currently registered to launch at login (system truth).
    var loginItemEnabled: @Sendable () -> Bool

    static func live() -> AppEnvironment {
        AppEnvironment(
            keyValue: UserDefaultsKeyValueStore(),
            timeZone: .current,
            now: { Date() },
            computeReadout: { date, timeZone, reuse in
                let events = try reuse ?? MoonAlmanac.lunationEvents(containing: date)
                return try MoonAlmanac.readout(at: date, timeZone: timeZone, events: events)
            },
            playHowl: playSound(named: "howl"),
            playHoot: playSound(named: "hoot"),
            setLoginItemEnabled: setLoginItem,
            loginItemEnabled: { SMAppService.mainApp.status == .enabled }
        )
    }

    private static let loginLog = Logger(subsystem: "com.heirloomlogic.Gibbous", category: "login-item")

    /// Register or unregister the app as a login item via ServiceManagement.
    /// Failures are logged, never fatal — the reducer reconciles state to the
    /// actual `SMAppService.mainApp.status` afterward.
    private static func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginLog.error("Failed to set login item to \(enabled): \(error.localizedDescription)")
        }
    }

    /// A cue that plays a bundled, licensed sound from Resources/Sounds.
    /// Gracefully no-ops if the asset can't be found or decoded.
    private static func playSound(named name: String) -> @Sendable () -> Void {
        {
            Task { @MainActor in
                guard
                    let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
                    let sound = NSSound(contentsOf: url, byReference: true)
                else { return }
                sound.play()
            }
        }
    }
}
