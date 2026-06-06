//
//  SettingsView.swift
//  Gibbous
//
//  The Settings window (⌘,). Mirrors the menu-bar quick toggles with a fuller
//  layout. All writes go through the store.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Look", selection: store.binding(\.displayStyle, sending: AppAction.setDisplayStyle)) {
                    Text("Modern").tag(DisplayStyle.modern)
                    Text("Retro").tag(DisplayStyle.retro)
                }
                Picker("Density", selection: store.binding(\.density, sending: AppAction.setDensity)) {
                    Text("Stats").tag(Density.stats)
                    Text("Moon only").tag(Density.moonOnly)
                }
            }
            Section("Companion") {
                Toggle(
                    "Always on top when torn off",
                    isOn: store.binding(\.alwaysOnTop, sending: AppAction.setAlwaysOnTop))
            }
            Section("Charm") {
                Toggle("Phase sounds", isOn: store.binding(\.soundsEnabled, sending: AppAction.setSoundsEnabled))
                Text("A wolf howl on the full moon. Off by default; bundled, licensed audio only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("About Gibbous…") { AboutWindow.show() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 340)
    }
}
