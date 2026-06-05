//
//  MoonAlmanac.swift
//  Gibbous
//
//  The pure data layer: one instant in, one `MoonReadout` out, computed from
//  AstronomyKit ephemeris plus the client-side `Derivations`. The AstronomyKit
//  Moon/Sun calls throw, so this throws too — callers surface a clean
//  "unavailable" state rather than crashing.
//

import Foundation
import AstronomyKit

nonisolated enum MoonAlmanac {
    static func readout(at date: Date, timeZone: TimeZone) throws -> MoonReadout {
        let t = AstroTime(date)

        let phaseAngle = try Moon.phaseAngle(at: t)
        let libration = Moon.libration(at: t)
        let sun = try Sun.position(at: t)

        let julianDate = Derivations.julianDate(j2000UTDays: t.universalTime)
        let sunKM = Derivations.sunDistanceKM(au: sun.distance)

        // The current lunation's phase events, anchored on the last new moon.
        let lastNew = try lastNewMoon(onOrBefore: t)
        let firstQuarter = try Moon.searchPhase(.firstQuarter, after: lastNew)
        let fullMoon = try Moon.searchPhase(.full, after: lastNew)
        let lastQuarter = try Moon.searchPhase(.thirdQuarter, after: lastNew)
        let nextNew = try Moon.searchPhase(.new, after: lastNew.addingDays(1))

        let lunation = Derivations.moonToolLunationNumber(
            newMoonJD: Derivations.julianDate(j2000UTDays: lastNew.universalTime)
        )

        return MoonReadout(
            now: date,
            timeZone: timeZone,
            phaseAngleDegrees: phaseAngle,
            illuminatedFraction: MoonGeometry.illuminatedFraction(phaseAngleDegrees: phaseAngle),
            isWaxing: MoonGeometry.isWaxing(phaseAngleDegrees: phaseAngle),
            phaseName: Moon.phaseName(for: phaseAngle),
            julianDate: julianDate,
            moonDistanceKM: libration.distanceKM,
            moonDistanceEarthRadii: Derivations.moonDistanceEarthRadii(km: libration.distanceKM),
            sunDistanceAU: sun.distance,
            sunDistanceKM: sunKM,
            moonSubtendDegrees: libration.apparentDiameter,
            sunSubtendDegrees: Derivations.sunAngularDiameterDegrees(sunDistanceKM: sunKM),
            lunationNumber: lunation,
            moonAge: Derivations.moonAge(from: lastNew.date, to: date),
            lastNewMoon: lastNew.date,
            firstQuarter: firstQuarter.date,
            fullMoon: fullMoon.date,
            lastQuarter: lastQuarter.date,
            nextNewMoon: nextNew.date,
            subEarthLatitude: libration.subEarthLatitude,
            subEarthLongitude: libration.subEarthLongitude
        )
    }

    /// The most recent new moon at or before `t`. Starts ~45 days back
    /// (longer than a synodic month, so at least one new moon precedes `t`)
    /// and walks forward, keeping the last new moon that doesn't pass `t`.
    static func lastNewMoon(onOrBefore t: AstroTime) throws -> AstroTime {
        var candidate = try Moon.searchPhase(.new, after: t.addingDays(-45))
        var last = candidate
        while candidate <= t {
            last = candidate
            candidate = try Moon.searchPhase(.new, after: candidate.addingDays(1))
        }
        return last
    }
}
