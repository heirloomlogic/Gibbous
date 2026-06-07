//
//  ShellViews.swift
//  Gibbous
//
//  Small AppKit-adjacent SwiftUI pieces: the About window helper.
//

import AppKit
import SwiftUI

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
