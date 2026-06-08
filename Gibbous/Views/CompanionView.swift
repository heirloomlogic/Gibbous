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

// MARK: - Liquid Glass support

/// Wraps content in a `GlassEffectContainer` on macOS 26+, and passes the
/// content through unchanged on earlier systems where the API is unavailable.
struct GlassStack<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// A Liquid Glass surface on macOS 26+, falling back to an ultra-thin
    /// material (over the popover's own material) on earlier systems.
    @ViewBuilder func glassSurface(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
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
