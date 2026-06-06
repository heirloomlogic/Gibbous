//
//  MenuBarController.swift
//  Gibbous
//
//  The AppKit shell. Owns the status item and its live phase glyph, and the
//  popdown (an NSPopover hosting the SwiftUI tree). Left-click toggles the
//  popdown; right-click opens a menu with the look switch and quick toggles.
//  One store drives everything.
//

import AppKit
import Observation
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let store: AppStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var glyphTimer: Timer?
    private var lastGlyphKey: String?

    init(store: AppStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
        refreshGlyph(force: true)
        startGlyphTimer()
        observeGlyphInputs()
    }

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Gibbous"
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return togglePopdown() }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopdown()
        }
    }

    // MARK: - Popdown

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: CompanionView().environment(store))
    }

    private func togglePopdown() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Context menu

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        for style in DisplayStyle.allCases {
            let item = NSMenuItem(
                title: style.rawValue.capitalized, action: #selector(menuSelectStyle), keyEquivalent: "")
            item.target = self
            item.state = store.displayStyle == style ? .on : .off
            item.representedObject = style
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let sounds = NSMenuItem(title: "Phase Sounds", action: #selector(menuToggleSounds), keyEquivalent: "")
        sounds.target = self
        sounds.state = store.soundsEnabled ? .on : .off
        menu.addItem(sounds)

        menu.addItem(.separator())
        menu.addItem(withAction: "About Gibbous", target: self, action: #selector(menuAbout))
        menu.addItem(withAction: "Quit Gibbous", target: self, action: #selector(menuQuit))

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func menuSelectStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? DisplayStyle else { return }
        store.send(.setDisplayStyle(style))
    }
    @objc private func menuToggleSounds() { store.send(.setSoundsEnabled(!store.soundsEnabled)) }
    @objc private func menuAbout() { AboutWindow.show() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - Glyph

    private func startGlyphTimer() {
        // Phase changes slowly; refresh the glyph on a coarse cadence.
        glyphTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshGlyph() }
        }
    }

    /// Re-render the glyph when the phase bucket or look changes.
    private func observeGlyphInputs() {
        withObservationTracking {
            _ = store.displayStyle
            _ = store.readout?.phaseName  // coarse: name changes ~per phase, not per second
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshGlyph()
                self?.observeGlyphInputs()
            }
        }
    }

    private func refreshGlyph(force: Bool = false) {
        let key = "\(store.displayStyle.rawValue)|\(store.readout.map { Int($0.phaseAngleDegrees) } ?? -1)"
        guard force || key != lastGlyphKey else { return }
        lastGlyphKey = key
        statusItem.button?.image = StatusItemGlyph.image(for: store.readout, style: store.displayStyle)
    }
}

extension NSMenu {
    fileprivate func addItem(withAction title: String, target: AnyObject, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        addItem(item)
    }
}
