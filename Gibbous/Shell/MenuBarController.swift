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
    private let hosting: NSHostingController<AnyView>
    private var glyphTimer: Timer?
    private var lastGlyphKey: String?

    init(store: AppStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hosting = NSHostingController(rootView: AnyView(CompanionView().environment(store)))
        super.init()
        // Track the SwiftUI intrinsic size so the popover resizes as the card
        // flips and as the skin changes (Modern ≈ 300pt, Retro ≈ 600pt, and the
        // settings backs differ again).
        hosting.sizingOptions = [.preferredContentSize]
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
        button.sendAction(on: [.leftMouseUp])
        // The product name — intentionally not localized (a proper noun), so it
        // stays a plain literal and out of the String Catalog.
        button.toolTip = "Gibbous"
    }

    @objc private func statusItemClicked() { togglePopdown() }

    // MARK: - Popdown

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
    }

    private func togglePopdown() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Always open to the front (skin) face, never mid-flip.
            store.send(.setShowingSettings(false))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate so the popover window becomes key: this makes its content
            // render in the system appearance immediately (not the default light
            // one) and lets the transient behavior dismiss on an outside click.
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

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
