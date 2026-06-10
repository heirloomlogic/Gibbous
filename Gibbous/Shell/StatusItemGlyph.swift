//
//  StatusItemGlyph.swift
//  Gibbous
//
//  Renders the live phase glyph for the menu bar via the shared MoonRenderer —
//  the same pipeline as the on-screen disc, just tiny. Falls back to an SF
//  Symbol when ephemeris or Metal is unavailable.
//

import AppKit

enum StatusItemGlyph {
    static func image(
        for readout: MoonReadout?,
        style: DisplayStyle,
        pointSize: CGFloat = 18,
        scale: CGFloat = 2
    ) -> NSImage {
        guard let readout, let renderer = MoonRenderer.shared else {
            return fallback(pointSize: pointSize)
        }
        // Lift the dark limb a touch so it reads against the menu bar. The disc
        // roll (axis position angle) carries through from the readout, so the
        // glyph rocks with the on-screen moon.
        let request = MoonRenderRequest(readout: readout, style: style, ambient: 0.05)

        let pixels = max(1, Int((pointSize * scale).rounded()))
        guard let cgImage = try? renderer.image(request, pixelSize: pixels) else {
            return fallback(pointSize: pointSize)
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: pointSize, height: pointSize))
        image.isTemplate = false  // full-colour / dithered, not a tint template
        return image
    }

    private static func fallback(pointSize: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Moon")?
            .withSymbolConfiguration(config)
        return image ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
    }
}
