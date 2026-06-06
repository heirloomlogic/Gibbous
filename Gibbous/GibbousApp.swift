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
        // Menu-bar accessory app: the real UI lives in the status item / floating
        // panel, and Settings is shown via SettingsWindow (the SwiftUI Settings
        // scene's open action does not surface for an .accessory app). This empty
        // scene just satisfies App's "needs a Scene" requirement.
        Settings { EmptyView() }
    }
}
