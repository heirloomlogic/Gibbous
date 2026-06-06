//
//  CompanionView.swift
//  Gibbous
//
//  The one SwiftUI tree hosted in the menu-bar popover. It routes the look axis
//  to one of the two personalities, both reading from the single store.
//

import SwiftUI

struct CompanionView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        content
            .animation(.smooth(duration: 0.25), value: store.displayStyle)
    }

    @ViewBuilder private var content: some View {
        switch store.displayStyle {
        case .modern: ModernView()
        case .retro: RetroView()
        }
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
