//
//  StatusItemGlyphTests.swift
//  GibbousTests
//
//  The menu-bar glyph: it falls back to an SF Symbol when there's no readout (or
//  Metal is unavailable), and otherwise renders the live disc and labels it with
//  the phase name for VoiceOver.
//

import AppKit
import Testing

@testable import Gibbous

@MainActor
struct StatusItemGlyphTests {
    @Test func fallsBackToAUsableImageWithoutAReadout() {
        // The SF-Symbol fallback's bounding box follows the symbol's metrics, not
        // the point size exactly — assert it's a valid, non-empty image.
        let image = StatusItemGlyph.image(for: nil, style: .modern, pointSize: 18)
        #expect(image.isValid)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test func rendersAtTheRequestedPointSizeForEitherSkin() throws {
        // The rendered disc is sized exactly to the point size; the fallback is
        // not, so this only holds where Metal is available.
        try #require(MoonRenderer.shared != nil, "no Metal device")
        for style in DisplayStyle.allCases {
            let image = StatusItemGlyph.image(for: SampleReadout.make(), style: style, pointSize: 22)
            #expect(image.size.width == 22)
        }
    }

    @Test func renderedGlyphAnnouncesTheLivePhaseForVoiceOver() throws {
        // Only the Metal-rendered path carries the phase name; the SF-Symbol
        // fallback doesn't, so skip the assertion where there's no GPU.
        try #require(MoonRenderer.shared != nil, "no Metal device")
        let r = SampleReadout.make()
        let image = StatusItemGlyph.image(for: r, style: .modern)
        #expect(image.accessibilityDescription == String(localized: r.phaseName))
        #expect(image.isTemplate == false)
    }
}
