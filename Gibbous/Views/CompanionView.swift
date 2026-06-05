//
//  CompanionView.swift
//  Gibbous
//
//  The one SwiftUI tree hosted in whichever container is active (popdown or
//  torn-off panel). It routes the two display axes — Look × Density — to the
//  four personalities, all reading from the single store.
//

import SwiftUI

struct CompanionView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        content
            .animation(.smooth(duration: 0.25), value: store.displayStyle)
            .animation(.smooth(duration: 0.25), value: store.density)
    }

    @ViewBuilder private var content: some View {
        switch (store.displayStyle, store.density) {
        case (.modern, .stats):     ModernView()
        case (.modern, .moonOnly):  ModernMoonOnlyView()
        case (.retro, .stats):      RetroView()
        case (.retro, .moonOnly):   RetroMoonOnlyView()
        }
    }
}

// MARK: - Shared look/density controls

/// A compact control row both skins place at their foot, styled by the caller.
struct LookDensityControls: View {
    @Environment(AppStore.self) private var store
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            toggle(title: store.displayStyle == .retro ? "Modern" : "Retro",
                   systemImage: "circle.lefthalf.filled") {
                store.send(.setDisplayStyle(store.displayStyle == .retro ? .modern : .retro))
            }
            toggle(title: store.density == .stats ? "Moon only" : "Stats",
                   systemImage: "rectangle.expand.vertical") {
                store.send(.setDensity(store.density == .stats ? .moonOnly : .stats))
            }
        }
        .font(.caption2)
        .foregroundStyle(tint)
        .buttonStyle(.plain)
    }

    private func toggle(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
        }
        .help(title)
    }
}

// MARK: - Unavailable / loading

/// Shown in place of the disc when ephemeris is unavailable.
struct MoonUnavailableView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
            Text("Moon unavailable").font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
