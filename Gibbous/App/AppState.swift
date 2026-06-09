//
//  AppState.swift
//  Gibbous
//
//  The single Swidux state container. Gibbous is deliberately small: the look
//  axis, the live clock, and the latest computed readout. No entities, no
//  SwiftData, no domain plugins — scalar preferences are persisted through
//  `KeyValueStore`, everything else is ephemeral session state.
//

import Foundation
@_exported import Swidux

/// The 1988-vs-2026 look axis.
nonisolated enum DisplayStyle: String, Codable, Sendable, CaseIterable {
    case modern, retro
}

@Swidux
nonisolated struct AppState: Equatable, Sendable {
    // Look (persisted).
    var displayStyle: DisplayStyle = .modern

    // Charm (persisted) — off by default.
    var soundsEnabled: Bool = false

    // Live session state (not persisted).
    var readout: MoonReadout? = nil
    var isUnavailable: Bool = false
    /// The upcoming full moon we've seen approaching this session — so we only
    /// howl on a live crossing, never for a full moon already past at launch.
    var armedFullMoon: Date? = nil
    /// The full moon we last fired the howl for, to debounce the charm cue.
    var lastFiredFullMoon: Date? = nil
    /// The most recent new moon we've already accounted for this session —
    /// seeded on the first readout so a new moon past at launch never hoots,
    /// then advanced (and fired) each time the clock crosses into a new lunation.
    var seenNewMoon: Date? = nil
}

// MARK: - Persisted preference keys

nonisolated extension KVKey where Value == DisplayStyle {
    static let displayStyle = KVKey<DisplayStyle>("displayStyle")
}
nonisolated extension KVKey where Value == Bool {
    static let soundsEnabled = KVKey<Bool>("soundsEnabled")
}

// MARK: - Hydration

nonisolated extension AppState {
    /// Build the initial state, pulling persisted preferences from the store.
    /// Reads happen once at launch; thereafter state is the source of truth.
    static func hydrated(from store: any KeyValueStore) -> AppState {
        var state = AppState()
        state.displayStyle = store.value(.displayStyle) ?? state.displayStyle
        state.soundsEnabled = store.value(.soundsEnabled) ?? state.soundsEnabled
        return state
    }
}
