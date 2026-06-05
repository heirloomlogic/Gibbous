//
//  GibbousApp.swift
//  Gibbous
//
//  Menu-bar agent app. The UI lives in the status item (and the torn-off
//  panel), so the only SwiftUI scene is Settings; the AppDelegate owns the
//  store and the menu-bar shell.
//

import SwiftUI

@main
struct GibbousApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.store)
        }
    }
}
