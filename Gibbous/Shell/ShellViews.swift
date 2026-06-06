//
//  ShellViews.swift
//  Gibbous
//
//  Small AppKit-adjacent SwiftUI pieces: the popdown wrapper with its tear-off
//  grip, and the About window helper.
//

import AppKit
import SwiftUI

/// The popdown content: a drag grip above the companion. Dragging the grip past
/// a threshold tears the companion off into a floating panel.
struct PopdownContainer: View {
    let onTearOff: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TearOffGrip(onTearOff: onTearOff)
            CompanionView()
        }
        .fixedSize()
    }
}

private struct TearOffGrip: View {
    let onTearOff: () -> Void
    @State private var fired = false

    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.45))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .help("Drag to tear off")
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { value in
                        let distance = hypot(value.translation.width, value.translation.height)
                        if !fired, distance > 22 {
                            fired = true
                            onTearOff()
                        }
                    }
                    .onEnded { _ in fired = false }
            )
    }
}

/// A single reusable About window.
@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: About())
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "About Gibbous"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
}

/// A single reusable Settings window. Owned directly (not a SwiftUI `Settings`
/// scene) because the scene's `showSettingsWindow:` action does not surface for
/// an `.accessory` menu-bar app. Mirrors `AboutWindow`.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(store: AppStore) {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView().environment(store))
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Gibbous Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
}
