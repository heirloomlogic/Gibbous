//
//  MoonPhaseDescriptor.swift
//  Gibbous
//
//  The Moon's *visual* phase — which named shape the disc reads as right now.
//  Unlike AstronomyKit's equal-45°-band naming (which calls a 56%-lit waxing
//  Moon "First Quarter"), the boundaries here sit on illuminated fraction, so the
//  visual anchors occupy the time each actually looks like itself: Full and New
//  persist for a couple of days (illumination barely moves near 0% and 100%),
//  while the Quarters last only about a day (it changes fastest at half-lit).
//

/// One of the eight named lunar phases, chosen from the current illumination and
/// waxing direction. Drives the hero headline (see `MoonReadout.phaseName`). The
/// principal phases (New, Quarter, Full) remain the *events* in the phase
/// timeline; this is the live description of the disc's present shape.
nonisolated enum MoonPhaseDescriptor: CaseIterable, Equatable {
    case newMoon
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case fullMoon
    case waningGibbous
    case lastQuarter
    case waningCrescent

    /// The phase the disc reads as at `illuminatedFraction` (0…1), given the
    /// waxing direction. Thresholds: New `< 2%`, Full `≥ 98%`, the Quarters
    /// `45–55%` (a ~day-wide window around half-lit), Crescent below that range,
    /// Gibbous above it.
    static func current(illuminatedFraction f: Double, isWaxing: Bool) -> MoonPhaseDescriptor {
        switch f {
        case ..<0.02: return .newMoon
        case 0.98...: return .fullMoon
        case 0.45...0.55: return isWaxing ? .firstQuarter : .lastQuarter
        case ..<0.45: return isWaxing ? .waxingCrescent : .waningCrescent
        default: return isWaxing ? .waxingGibbous : .waningGibbous
        }
    }
}
