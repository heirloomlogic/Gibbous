//
//  MoonReadout.swift
//  Gibbous
//
//  The full set of values Gibbous shows for one instant — raw numbers plus the
//  current lunation's phase-event timeline and the libration angles the disc
//  renderer needs. A pure value type; `MoonAlmanac` produces it from ephemeris.
//

import Foundation

nonisolated struct MoonReadout: Equatable, Sendable {
    /// The instant this readout describes.
    var now: Date
    /// The timezone for displaying local times (the clock, phase events).
    var timeZone: TimeZone

    // MARK: Phase
    /// Phase angle in degrees (0 = new, 90 = first quarter, 180 = full, 270 = third).
    var phaseAngleDegrees: Double
    /// Illuminated fraction of the disc, 0…1.
    var illuminatedFraction: Double
    /// Whether the Moon is waxing (phase angle < 180°).
    var isWaxing: Bool

    // MARK: Time / distance / size
    var julianDate: Double
    var moonDistanceKM: Double
    var moonDistanceEarthRadii: Double
    var sunDistanceAU: Double
    var sunDistanceKM: Double
    /// Moon's apparent angular diameter in degrees.
    var moonSubtendDegrees: Double
    /// Sun's apparent angular diameter in degrees.
    var sunSubtendDegrees: Double

    // MARK: Lunation
    /// Moon Tool's displayed lunation number (standard Brown number + 1).
    var lunationNumber: Int
    var moonAge: MoonAge

    /// The current lunation's phase events.
    var lastNewMoon: Date
    var firstQuarter: Date
    var fullMoon: Date
    var lastQuarter: Date
    var nextNewMoon: Date

    // MARK: Libration (for the disc renderer)
    /// Sub-Earth latitude — the disc's north/south tilt toward the viewer.
    var subEarthLatitude: Double
    /// Sub-Earth longitude — the disc's east/west tilt toward the viewer.
    var subEarthLongitude: Double
    /// Position angle of the Moon's north pole, degrees CCW from celestial north
    /// — the disc's apparent roll (how far the pole leans from straight-up). This
    /// is the dominant part of the libration "rock" seen as the lunation advances.
    var axisPositionAngleDegrees: Double = 0

    // MARK: Special full moon
    /// The full moon's formal special-moon name (blue / harvest / hunter / super),
    /// or `nil`. Fixed for the lunation; surfaced in the headline only while the
    /// disc actually reads as full (see `phaseHeadline`).
    var specialFullMoon: SpecialFullMoonKind? = nil
}
