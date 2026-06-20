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
        CardCrossfade(flipped: store.isShowingSettings) {
            frontFace
        } back: {
            SettingsPane()
        }
        .animation(.smooth(duration: 0.30), value: store.isShowingSettings)
        .animation(.smooth(duration: 0.25), value: store.displayStyle)
    }

    /// The current skin, with the ⓘ that turns the card over to the settings
    /// face. Modern tucks a glass ⓘ into the top-right of its hero card; Retro
    /// sits a System-7 ⓘ baseline-aligned with the "Moon" / "Phases" titles.
    @ViewBuilder private var frontFace: some View {
        switch store.displayStyle {
        case .modern:
            ModernView()
                .overlay(alignment: .topTrailing) {
                    FaceCornerButton(systemName: "info") {
                        store.send(.setShowingSettings(true))
                    }
                    // Sits in the right column's first section-label band, clear of
                    // the ledger box below it.
                    .padding(.top, 6)
                    .padding(.trailing, 14)
                }
        case .retro:
            RetroView()
                .overlay(alignment: .topTrailing) {
                    RetroCornerButton(systemName: "info.square") {
                        store.send(.setShowingSettings(true))
                    }
                    .padding(.top, 3)
                    .padding(.trailing, 9)
                }
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

    /// As `glassSurface(in:)`, but pins the surface to a stable identity within a
    /// namespace so a resize re-renders the same shape in place instead of letting
    /// the container flow geometry between untracked blobs.
    @ViewBuilder func glassSurface(
        in shape: some Shape, id: some Hashable & Sendable, namespace: Namespace.ID
    ) -> some View {
        if #available(macOS 26, *) {
            glassEffect(in: shape).glassEffectID(id, in: namespace)
        } else {
            glassSurface(in: shape)
        }
    }
}

// MARK: - Unavailable / loading

/// Shown in place of the disc when ephemeris is unavailable.
struct MoonUnavailableView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
            Text(ReadoutCopy.unavailable).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview("Companion — Modern") {
    CompanionView().environment(AppStore.preview(style: .modern))
}

#Preview("Companion — Retro") {
    CompanionView().environment(AppStore.preview(style: .retro))
}

#Preview("Companion — Settings face") {
    CompanionView().environment(AppStore.preview(style: .modern, showingSettings: true))
}
#endif
