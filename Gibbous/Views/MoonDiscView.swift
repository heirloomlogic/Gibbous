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
    /// Retro dither cell size, in points (the stipple dot scale). Defaults to the
    /// tuned value; exposed so previews/tuning can scrub it.
    var retroPointsPerCell: CGFloat = MoonDiscNSView.defaultRetroPointsPerCell

    func makeNSView(context: Context) -> MoonDiscNSView {
        let view = MoonDiscNSView()
        view.retroPointsPerCell = retroPointsPerCell
        view.request = request
        return view
    }

    func updateNSView(_ view: MoonDiscNSView, context: Context) {
        view.retroPointsPerCell = retroPointsPerCell
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

    /// Retro dither cell size, in points. The disc renders at full resolution so
    /// the limb stays round, while each ~`retroPointsPerCell`-point cell resolves
    /// to one chunky 1-bit block — the bold stipple of the 1988 tools (a 1-pixel
    /// cell on Retina would average into smooth grey).
    static let defaultRetroPointsPerCell: CGFloat = 1.0
    var retroPointsPerCell: CGFloat = defaultRetroPointsPerCell {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }
    override var isFlipped: Bool { true }

    override func updateLayer() {
        guard let request, let renderer = MoonRenderer.shared else { return }
        let scale = window?.backingScaleFactor ?? 2
        let side = min(bounds.width, bounds.height)
        let pixels = Int((side * scale).rounded())
        guard pixels > 0 else { return }

        var req = request
        if req.look == .retro {
            req.ditherCell = Float(max(1, Int((retroPointsPerCell * scale).rounded())))
        }

        // Skip redundant renders — the request (phase, look, libration, dither…)
        // and pixel size fully determine the image.
        guard rendered?.request != req || rendered?.pixels != pixels else { return }

        if let image = try? renderer.image(req, pixelSize: pixels) {
            layer?.contents = image
            layer?.contentsGravity = .resizeAspect
            // Keep retro's blocky cells crisp; Modern stays smoothly filtered.
            layer?.magnificationFilter = req.look == .retro ? .nearest : .linear
            rendered = (req, pixels)
        }
    }

    override func layout() {
        super.layout()
        needsDisplay = true  // size may have changed → updateLayer re-checks
    }
}

#if DEBUG
/// Live tuning harness for the retro 1-bit moon. Scrub the phase and the dither
/// knobs and watch the disc update — far faster than rebuilding the app. The
/// values here mirror the `MoonRenderRequest` defaults, so a good combination
/// found in the canvas can be copied straight back into `MoonRenderRequest`.
private struct RetroMoonTuningPreview: View {
    @State private var phaseAngle = 40.0  // ~15% waxing crescent, like the screenshots
    @State private var earthshine = 0.07
    @State private var blackPoint = 0.04
    @State private var gamma = 0.85
    @State private var pointsPerCell = 1.0

    private var request: MoonRenderRequest {
        var r = MoonRenderRequest(
            phaseAngleDegrees: phaseAngle,
            look: .retro,
            transparentOutside: false,
            backgroundColor: SIMD4(0.05, 0.05, 0.06, 1))
        r.retroEarthshine = Float(earthshine)
        r.retroBlackPoint = Float(blackPoint)
        r.retroGamma = Float(gamma)
        return r
    }

    var body: some View {
        HStack(spacing: 20) {
            MoonDiscView(request: request, retroPointsPerCell: pointsPerCell)
                .frame(width: 280, height: 280)
                .background(.black)

            VStack(alignment: .leading, spacing: 12) {
                knob("Phase", $phaseAngle, 0...180)
                knob("Earthshine", $earthshine, 0...0.30)
                knob("Black point", $blackPoint, 0...0.15)
                knob("Gamma", $gamma, 0.30...1.50)
                knob("Dot size (pt)", $pointsPerCell, 0.50...3.00)
            }
            .frame(width: 260)
        }
        .padding(20)
        .frame(width: 600, height: 340)
    }

    private func knob(
        _ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(value.wrappedValue, specifier: "%.3f")")
                .font(.caption.monospaced())
            Slider(value: value, in: range)
        }
    }
}

#Preview("Retro moon — tuning") {
    RetroMoonTuningPreview()
}
#endif
