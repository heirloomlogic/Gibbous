//
//  MoonGeometry.swift
//  Gibbous
//
//  The disc's terminator geometry, shared by the renderer and the readout.
//  Pure trigonometry — illuminated fraction and the waxing/waning side from
//  the phase angle (0 = new, 90 = first quarter, 180 = full, 270 = third).
//

import Foundation

nonisolated enum MoonGeometry {
    /// Illuminated fraction of the disc: f = (1 − cos φ) / 2.
    static func illuminatedFraction(phaseAngleDegrees phi: Double) -> Double {
        (1 - cos(phi * .pi / 180)) / 2
    }

    /// Whether the Moon is waxing — phase angle in [0°, 180°). The lit limb is
    /// on the right (Northern Hemisphere) while waxing, on the left while waning.
    static func isWaxing(phaseAngleDegrees phi: Double) -> Bool {
        let normalized = ((phi.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        return normalized < 180
    }
}
