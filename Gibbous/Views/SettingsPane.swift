//
//  SettingsPane.swift
//  Gibbous
//
//  The back of the popover card — the skin switch, the Phase Sounds charm, the
//  credits, and Quit, all moved out of the (undiscoverable) right-click menu.
//  Like the front, the back is theme-aware: Modern flips to a glass settings
//  card, Retro flips to a System-7 "Control Panel" dialog. Changing the skin
//  here re-themes both faces live.
//

import AppKit
import SwiftUI

/// Single source of truth for the credit copy — names the originals and
/// AstronomyKit per the legal guardrails, and keeps the one quiet door to the
/// rest of Heirloom Logic. Both skins render these exact strings.
enum AboutCopy {
    static let name = "Gibbous"
    static let tagline = "A charming menu-bar moon companion for the Mac."
    static let homage =
        """
        A homage to Moontool by John Walker (1988) and the Macintosh Moon Tool \
        by Richard Knuckey. Built on AstronomyKit.
        """
    static let observatoryHeader = "FROM THE SAME OBSERVATORY"
    static let observatoryBody =
        """
        Fallow, a celestial almanac for lunar practice, and Edict, an observatory \
        for timing what matters — both read from the same sky.
        """
    static let linkLabel = "Coming from Heirloom Logic"
    static let heirloomURL = URL(string: "https://github.com/heirloomlogic")
}

extension View {
    /// Shows the pointing-hand cursor while the pointer is over an interactive
    /// control — the app doesn't use HeirloomKit, so it supplies its own.
    func pointerCursor() -> some View {
        onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// Routes the back face to the personality matching the current skin.
struct SettingsPane: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.displayStyle {
        case .modern: ModernSettingsView()
        case .retro: RetroSettingsView()
        }
    }
}

// MARK: - Modern (glass settings card)

struct ModernSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        GlassStack(spacing: 12) {
            VStack(spacing: 12) {
                controls
                about
            }
            .padding(12)
        }
        .frame(width: 300)
        .foregroundStyle(.primary)
        // Overlaid outside the GlassStack — like the front ⓘ — so its glass
        // circle reads as its own shape instead of merging into the card. The
        // 22pt inset lands it 10pt inside the controls card's top-right corner.
        .overlay(alignment: .topTrailing) {
            FaceCornerButton(systemName: "xmark") {
                store.send(.setShowingSettings(false))
            }
            .padding([.top, .trailing], 22)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Skin").font(.callout).foregroundStyle(.secondary)
                Picker("Skin", selection: skinBinding) {
                    Text("Modern").tag(DisplayStyle.modern)
                    Text("Retro").tag(DisplayStyle.retro)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .pointerCursor()
            }
            Toggle(isOn: soundsBinding) {
                Text("Phase Sounds").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pointerCursor()
            Button("Quit Gibbous") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(in: .rect(cornerRadius: 16))
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 32)).foregroundStyle(.secondary)
            Text(AboutCopy.name).font(.title3.weight(.semibold))
            Text(AboutCopy.tagline)
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(AboutCopy.homage)
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Divider().frame(width: 180)
            Text(AboutCopy.observatoryHeader)
                .font(.caption2.weight(.medium)).tracking(0.75).foregroundStyle(.tertiary)
            Text(AboutCopy.observatoryBody)
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let url = AboutCopy.heirloomURL {
                Link(AboutCopy.linkLabel, destination: url)
                    .font(.caption.weight(.medium))
                    .pointerCursor()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassSurface(in: .rect(cornerRadius: 16))
    }

    private var skinBinding: Binding<DisplayStyle> {
        Binding(get: { store.displayStyle }, set: { store.send(.setDisplayStyle($0)) })
    }
    private var soundsBinding: Binding<Bool> {
        Binding(get: { store.soundsEnabled }, set: { store.send(.setSoundsEnabled($0)) })
    }
}

/// A round Liquid-Glass corner control for the Modern face: a bare glyph
/// ("info" / "xmark") centred in a glass circle, tucked into the top-right of
/// the first section.
struct FaceCornerButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .glassSurface(in: .circle)
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

// MARK: - Retro (System-7 Control Panel)

struct RetroSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RetroGroupBox(title: "Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    RetroRadio(label: "Modern", selected: store.displayStyle == .modern) {
                        store.send(.setDisplayStyle(.modern))
                    }
                    RetroRadio(label: "Retro", selected: store.displayStyle == .retro) {
                        store.send(.setDisplayStyle(.retro))
                    }
                    RetroCheckbox(label: "Phase Sounds", on: store.soundsEnabled) {
                        store.send(.setSoundsEnabled(!store.soundsEnabled))
                    }
                    RetroPushButton(label: "Quit") { NSApplication.shared.terminate(nil) }
                        .padding(.top, 2)
                }
            }
            RetroGroupBox(title: "About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AboutCopy.name).font(RetroTheme.font(14))
                    Text(AboutCopy.tagline)
                        .font(RetroTheme.font(11)).foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AboutCopy.homage)
                        .font(RetroTheme.font(11)).foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AboutCopy.observatoryHeader)
                        .font(RetroTheme.font(11))
                    Text(AboutCopy.observatoryBody)
                        .font(RetroTheme.font(11)).foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = AboutCopy.heirloomURL {
                        Link(AboutCopy.linkLabel, destination: url)
                            .font(RetroTheme.font(11))
                            .pointerCursor()
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .foregroundStyle(palette.ink)
        .overlay(alignment: .topTrailing) {
            RetroCornerButton(systemName: "xmark.square") {
                store.send(.setShowingSettings(false))
            }
            .padding(.top, 8)
            .padding(.trailing, 14)
        }
    }
}

/// A System-7 corner control: an ink-coloured square SF Symbol (the ⓘ that
/// flips to settings, the ✕ that flips back), baseline-aligned with the first
/// section title of the face it sits on.
struct RetroCornerButton: View {
    let systemName: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundStyle(palette.ink)
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// A System-7 radio: an outlined ring with a filled centre when chosen.
private struct RetroRadio: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(palette.ink, lineWidth: 1).frame(width: 13, height: 13)
                    if selected { Circle().fill(palette.ink).frame(width: 7, height: 7) }
                }
                Text(label).font(RetroTheme.font(11))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// A System-7 checkbox: an outlined square with an ✕ when checked.
private struct RetroCheckbox: View {
    let label: String
    let on: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Rectangle().strokeBorder(palette.ink, lineWidth: 1).frame(width: 13, height: 13)
                    if on {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(palette.ink)
                    }
                }
                Text(label).font(RetroTheme.font(11))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// A System-7 push button: a Chicago label in a 1px-bordered rounded rectangle.
struct RetroPushButton: View {
    let label: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(RetroTheme.font(11))
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 9).strokeBorder(palette.ink, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}
