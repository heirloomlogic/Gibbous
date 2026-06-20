//
//  PreviewSupportTests.swift
//  GibbousTests
//
//  The DEBUG preview fixtures: the sample readout is self-consistent, and the
//  preview store reflects the requested skin / readout / settings face. Keeping
//  these honest means the SwiftUI canvas shows what the views actually render.
//

import Foundation
import Testing

@testable import Gibbous

@MainActor
struct PreviewSupportTests {
    @Test func sampleReadoutIsSelfConsistent() {
        let r = MoonReadout.preview
        #expect(r.isWaxing)
        #expect(r.illuminatedFraction > 0 && r.illuminatedFraction < 1)
        #expect(r.lastNewMoon < r.fullMoon)
        #expect(r.fullMoon < r.nextNewMoon)
        #expect(r.containsLunation(of: r.now))
    }

    @Test func previewStoreReflectsTheRequestedSkinAndReadout() {
        let modern = AppStore.preview(style: .modern)
        #expect(modern.displayStyle == .modern)
        #expect(modern.readout == .preview)
        #expect(modern.isShowingSettings == false)

        let retroSettings = AppStore.preview(style: .retro, showingSettings: true)
        #expect(retroSettings.displayStyle == .retro)
        #expect(retroSettings.isShowingSettings)
    }

    @Test func previewStoreWithoutAReadoutModelsTheUnavailableState() {
        let store = AppStore.preview(readout: nil)
        #expect(store.readout == nil)
    }
}
