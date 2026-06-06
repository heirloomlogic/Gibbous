//
//  MenuBarController.swift
//  Gibbous
//
//  The AppKit shell. Owns the status item and its live phase glyph, the
//  popdown (an NSPopover hosting the SwiftUI tree), and the torn-off floating
//  panel. Left-click toggles the popdown; right-click opens a menu with the
//  Tear Off / Rejoin commands (the signature gesture also works by dragging the
//  grip at the top of the popdown). One store drives everything.
//

import AppKit
import Observation
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let store: AppStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var floatingPanel: FloatingPanel?
    private var glyphTimer: Timer?
    private var lastGlyphKey: String?

    init(store: AppStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
        restoreFloatingPanelIfNeeded()
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
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopdownContainer(onTearOff: { [weak self] in self?.tearOff() })
                .environment(store))
    }

    private func togglePopdown() {
        if let panel = floatingPanel {
            panel.makeKeyAndOrderFront(nil)  // already torn off → focus it
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Tear off / rejoin

    private func tearOff() {
        guard floatingPanel == nil else { return }
        popover.performClose(nil)
        presentFloatingPanel(at: nil)  // signature gesture: open at the cursor
        store.send(.setPresentation(.floating))
    }

    /// Reopen a torn-off panel at launch if that's where we left off.
    private func restoreFloatingPanelIfNeeded() {
        guard store.presentation == .floating else { return }
        presentFloatingPanel(at: store.floatingFrame)  // presentation already .floating
    }

    /// Build and show the floating panel. `frame` restores a saved position
    /// (clamped to a visible screen); `nil` opens at the cursor.
    private func presentFloatingPanel(at frame: CGRect?) {
        guard floatingPanel == nil else { return }

        let panel = FloatingPanel(
            rootView: CompanionView().environment(store),
            alwaysOnTop: store.alwaysOnTop)
        panel.onClose = { [weak self] in self?.handlePanelClosed() }
        panel.onFrameChange = { [weak self] in self?.store.send(.setFloatingFrame($0)) }
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 280, height: 360))

        if let frame, isOnScreen(frame) {
            panel.setFrame(frame, display: false)
        } else {
            positionAtCursor(panel)
        }
        panel.makeKeyAndOrderFront(nil)

        floatingPanel = panel
    }

    /// Whether a saved frame still overlaps a connected screen (displays may
    /// have changed since it was saved).
    private func isOnScreen(_ frame: CGRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    private func rejoin() {
        floatingPanel?.close()  // triggers handlePanelClosed via onClose
    }

    private func handlePanelClosed() {
        floatingPanel = nil
        store.send(.setPresentation(.menuBarPopdown))
    }

    private func positionAtCursor(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        panel.setFrameTopLeftPoint(NSPoint(x: mouse.x - size.width / 2, y: mouse.y))
    }

    // MARK: - Context menu

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        if floatingPanel == nil {
            menu.addItem(withAction: "Tear Off", target: self, action: #selector(menuTearOff))
        } else {
            menu.addItem(withAction: "Rejoin Menu Bar", target: self, action: #selector(menuRejoin))
        }

        let pin = NSMenuItem(title: "Always on Top", action: #selector(menuToggleAlwaysOnTop), keyEquivalent: "")
        pin.target = self
        pin.state = store.alwaysOnTop ? .on : .off
        menu.addItem(pin)

        let sounds = NSMenuItem(title: "Phase Sounds", action: #selector(menuToggleSounds), keyEquivalent: "")
        sounds.target = self
        sounds.state = store.soundsEnabled ? .on : .off
        menu.addItem(sounds)

        menu.addItem(.separator())
        menu.addItem(withAction: "About Gibbous", target: self, action: #selector(menuAbout))
        menu.addItem(withAction: "Settings…", target: self, action: #selector(menuSettings))
        menu.addItem(.separator())
        menu.addItem(withAction: "Quit Gibbous", target: self, action: #selector(menuQuit))

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func menuTearOff() { tearOff() }
    @objc private func menuRejoin() { rejoin() }
    @objc private func menuToggleAlwaysOnTop() {
        let next = !store.alwaysOnTop
        store.send(.setAlwaysOnTop(next))
        floatingPanel?.setAlwaysOnTop(next)
    }
    @objc private func menuToggleSounds() { store.send(.setSoundsEnabled(!store.soundsEnabled)) }
    @objc private func menuAbout() {
        AboutWindow.show()
    }
    @objc private func menuSettings() { SettingsWindow.show(store: store) }
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

    // MARK: - NSPopoverDelegate (drag-off detaches into the floating panel)

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }
}

extension NSMenu {
    fileprivate func addItem(withAction title: String, target: AnyObject, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        addItem(item)
    }
}
