//
//  MoonGeometry.swift
//  Gibbous
//
//  The disc's terminator geometry, shared by the renderer and the readout.
//  Pure trigonometry — illuminated fraction and the waxing/waning side from
//  the phase angle (0 = new, 90 = first quarter, 180 = full, 270 = third).
//

import Foundation
import simd

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

    /// Position angle of the Moon's north pole, measured from celestial north
    /// toward east, in degrees. `moonDirection` is the geocentric direction to
    /// the Moon's centre and `northPole` the direction to its north pole — both
    /// in the same equatorial frame (J2000), not necessarily unit length.
    ///
    /// This is the disc's apparent roll: 0 means the pole points straight up
    /// (north up), positive leans it toward east. We project both the pole and
    /// celestial north onto the plane of the sky (perpendicular to the line of
    /// sight) and take the angle between them.
    static func axisPositionAngleDegrees(
        moonDirection m: SIMD3<Double>,
        northPole pn: SIMD3<Double>
    ) -> Double {
        let los = simd_normalize(m)  // line of sight, Earth → Moon
        let celestialNorth = SIMD3<Double>(0, 0, 1)
        // Sky-plane basis at the Moon: east = increasing RA, north = increasing Dec.
        let east = simd_normalize(simd_cross(celestialNorth, los))
        let north = simd_cross(los, east)
        // Pole projected onto the plane of sky.
        let poleProj = pn - simd_dot(pn, los) * los
        return atan2(simd_dot(poleProj, east), simd_dot(poleProj, north)) * 180 / .pi
    }
}
