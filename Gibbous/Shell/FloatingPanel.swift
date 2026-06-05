//
//  FloatingPanel.swift
//  Gibbous
//
//  The torn-off desktop companion: a non-activating panel that hosts the same
//  SwiftUI tree as the popdown. Movable by its background, optionally pinned
//  always-on-top, and it reports closing/moving back so the controller can
//  restore popdown behaviour.
//

import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    var onClose: (() -> Void)?

    init(rootView: some View, alwaysOnTop: Bool) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = alwaysOnTop ? .floating : .normal
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        backgroundColor = .clear
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingController(rootView: rootView)
        contentViewController = hosting
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func close() {
        onClose?()
        super.close()
    }
}
