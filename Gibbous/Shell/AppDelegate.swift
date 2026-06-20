//
//  AppDelegate.swift
//  Gibbous
//
//  Owns the store and the menu-bar shell. Runs as a menu-bar accessory (no Dock
//  icon); starts the clock once the app is up.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore.configured()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        RetroFont.registerBundledFonts()
        menuBar = MenuBarController(store: store)
        store.send(.startClock)
        store.send(.syncLaunchAtLogin)
    }
}
