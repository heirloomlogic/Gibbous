//
//  MenuBarControllerTests.swift
//  GibbousTests
//
//  The AppKit shell's store-facing behavior: it stands up without crashing, and
//  its popover-visibility delegate callbacks drive the recompute-cadence flag.
//  The click/menu plumbing itself needs a live status bar and isn't unit-tested.
//

import AppKit
import Testing

@testable import Gibbous

@MainActor
struct MenuBarControllerTests {
    @Test func controllerStandsUpWithoutCrashing() {
        let store = AppStore.stub()
        _ = MenuBarController(store: store)
        // Reaching here means the status item, popover, glyph and observation
        // were all configured.
    }

    @Test func popoverVisibilityCallbacksDriveTheShownFlag() {
        let store = AppStore.stub()
        let controller = MenuBarController(store: store)
        let note = Notification(name: NSPopover.didShowNotification)

        controller.popoverDidShow(note)
        #expect(store.isPopoverShown)

        controller.popoverDidClose(note)
        #expect(store.isPopoverShown == false)
    }
}
