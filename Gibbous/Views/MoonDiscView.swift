//
//  MoonDiscView.swift
//  Gibbous
//
//  SwiftUI wrapper around the Metal sphere-impostor renderer. The disc is
//  always transparent outside its circle, so SwiftUI owns the background; the
//  same renderer (and the same request type) also produces the menu-bar glyph.
//  We redraw only when the request or the view's pixel size changes.
//

import SwiftUI

struct MoonDiscView: NSViewRepresentable {
    var request: MoonRenderRequest

    func makeNSView(context: Context) -> MoonDiscNSView {
        let view = MoonDiscNSView()
        view.request = request
        return view
    }

    func updateNSView(_ view: MoonDiscNSView, context: Context) {
        view.request = request
    }
}

/// Layer-backed view that renders the moon to a `CGImage` and shows it as its
/// layer contents, re-rendering when the request or backing size changes.
final class MoonDiscNSView: NSView {
    var request: MoonRenderRequest? {
        didSet { needsDisplay = true }
    }

    private var rendered: (request: MoonRenderRequest, pixels: Int)?

    override var wantsUpdateLayer: Bool { true }
    override var isFlipped: Bool { true }

    override func updateLayer() {
        guard let request, let renderer = MoonRenderer.shared else { return }
        let scale = window?.backingScaleFactor ?? 2
        let side = min(bounds.width, bounds.height)
        let pixels = Int((side * scale).rounded())
        guard pixels > 0 else { return }

        // Skip redundant renders — the request (phase, look, libration, dither…)
        // and pixel size fully determine the image.
        guard rendered?.request != request || rendered?.pixels != pixels else { return }

        if let image = try? renderer.image(request, pixelSize: pixels) {
            layer?.contents = image
            layer?.contentsGravity = .resizeAspect
            rendered = (request, pixels)
        }
    }

    override func layout() {
        super.layout()
        needsDisplay = true  // size may have changed → updateLayer re-checks
    }
}
