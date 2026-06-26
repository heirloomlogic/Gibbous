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
    let store = AppDelegate.makeStore()
    private var menuBar: MenuBarController?

    /// The store for an app launch. Identical to `AppStore.configured()`, except
    /// a DEBUG build launched in snapshot mode freezes the clock at a fixed
    /// waxing-gibbous instant for consistent screenshots (see SnapshotMode).
    private static func makeStore() -> AppStore {
        #if DEBUG
        return AppStore.configured(environment: SnapshotMode.environment(.live()))
        #else
        return AppStore.configured()
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        RetroFont.registerBundledFonts()
        menuBar = MenuBarController(store: store)
        store.send(.startClock)
        store.send(.syncLaunchAtLogin)
    }
}
