//
//  AppState.swift
//  Gibbous
//
//  The single Swidux state container. Gibbous is deliberately small: two
//  display axes, the presentation/window state, the live clock, and the latest
//  computed readout. No entities, no SwiftData, no domain plugins — scalar
//  preferences are persisted through `KeyValueStore`, everything else is
//  ephemeral session state.
//

import CoreGraphics
import Foundation
@_exported import Swidux

/// The 1988-vs-2026 look axis.
nonisolated enum DisplayStyle: String, Codable, Sendable, CaseIterable {
    case modern, retro
}

/// The chrome-density axis.
nonisolated enum Density: String, Codable, Sendable, CaseIterable {
    case stats      // full readout
    case moonOnly   // just the disc
}

/// Where the companion currently lives.
nonisolated enum Presentation: String, Codable, Sendable {
    case menuBarPopdown   // anchored to the status item
    case floating         // torn off into a desktop panel
}

@Swidux
nonisolated struct AppState: Equatable, Sendable {
    // Display axes (persisted).
    var displayStyle: DisplayStyle = .modern
    var density: Density = .stats

    // Presentation / window (persisted).
    var presentation: Presentation = .menuBarPopdown
    var floatingFrame: CGRect = CGRect(x: 0, y: 0, width: 280, height: 360)
    var alwaysOnTop: Bool = false

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
}

// MARK: - Persisted preference keys

nonisolated extension KVKey where Value == DisplayStyle {
    static let displayStyle = KVKey<DisplayStyle>("displayStyle")
}
nonisolated extension KVKey where Value == Density {
    static let density = KVKey<Density>("density")
}
nonisolated extension KVKey where Value == Presentation {
    static let presentation = KVKey<Presentation>("presentation")
}
nonisolated extension KVKey where Value == CGRect {
    static let floatingFrame = KVKey<CGRect>("floatingFrame")
}
nonisolated extension KVKey where Value == Bool {
    static let alwaysOnTop = KVKey<Bool>("alwaysOnTop")
    static let soundsEnabled = KVKey<Bool>("soundsEnabled")
}

// MARK: - Hydration

nonisolated extension AppState {
    /// Build the initial state, pulling persisted preferences from the store.
    /// Reads happen once at launch; thereafter state is the source of truth.
    static func hydrated(from store: any KeyValueStore) -> AppState {
        var state = AppState()
        state.displayStyle = store.value(.displayStyle) ?? state.displayStyle
        state.density = store.value(.density) ?? state.density
        state.presentation = store.value(.presentation) ?? state.presentation
        state.alwaysOnTop = store.value(.alwaysOnTop) ?? state.alwaysOnTop
        state.soundsEnabled = store.value(.soundsEnabled) ?? state.soundsEnabled
        if let frame = store.value(.floatingFrame) { state.floatingFrame = frame }
        return state
    }
}
