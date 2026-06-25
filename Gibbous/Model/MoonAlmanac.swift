//
//  MoonAlmanac.swift
//  Gibbous
//
//  The pure data layer: one instant in, one `MoonReadout` out, computed from
//  AstronomyKit ephemeris plus the client-side `Derivations`. The AstronomyKit
//  Moon/Sun calls throw, so this throws too — callers surface a clean
//  "unavailable" state rather than crashing.
//

import AstronomyKit
import Foundation

/// The five phase events of one lunation plus its lunation number. These are
/// fixed for the whole ~29.5-day lunation, so they're computed once (the
/// expensive `searchPhase` root-finding) and reused across clock ticks until
/// "now" crosses into the next lunation. See `AppReducer.tick`.
nonisolated struct LunationEvents: Sendable, Equatable {
    let lastNewMoon: Date
    let firstQuarter: Date
    let fullMoon: Date
    let lastQuarter: Date
    let nextNewMoon: Date
    let lunationNumber: Int
}

nonisolated enum MoonAlmanac {
    /// Fresh readout for an instant — computes the lunation events too. Used by
    /// tests and any caller without a cached lunation to reuse.
    static func readout(at date: Date, timeZone: TimeZone) throws -> MoonReadout {
        try readout(at: date, timeZone: timeZone, events: lunationEvents(containing: date))
    }

    /// Readout for an instant given its lunation's (precomputed) phase events.
    /// Only the cheap instantaneous queries run here — the expensive phase
    /// searches live in `lunationEvents(containing:)`.
    static func readout(
        at date: Date, timeZone: TimeZone,
        events: LunationEvents
    ) throws -> MoonReadout {
        let t = AstroTime(date)

        let phaseAngle = try Moon.phaseAngle(at: t)
        let libration = Moon.libration(at: t)
        let sun = try Sun.position(at: t)

        // The disc's apparent roll: the position angle of the Moon's north pole.
        // Both the Moon's geocentric direction and its pole vector come back in
        // the J2000 equatorial frame, so they share a frame for the PA math.
        let moonVector = try CelestialBody.moon.geocentricPosition(at: t)
        let moonAxis = try CelestialBody.moon.rotationAxis(at: t)
        let axisPositionAngle = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(moonVector.x, moonVector.y, moonVector.z),
            northPole: SIMD3(moonAxis.north.x, moonAxis.north.y, moonAxis.north.z))

        let julianDate = Derivations.julianDate(j2000UTDays: t.universalTime)
        let sunKM = Derivations.sunDistanceKM(au: sun.distance)

        return MoonReadout(
            now: date,
            timeZone: timeZone,
            phaseAngleDegrees: phaseAngle,
            illuminatedFraction: MoonGeometry.illuminatedFraction(phaseAngleDegrees: phaseAngle),
            isWaxing: MoonGeometry.isWaxing(phaseAngleDegrees: phaseAngle),
            julianDate: julianDate,
            moonDistanceKM: libration.distanceKM,
            moonDistanceEarthRadii: Derivations.moonDistanceEarthRadii(km: libration.distanceKM),
            sunDistanceAU: sun.distance,
            sunDistanceKM: sunKM,
            moonSubtendDegrees: libration.apparentDiameter,
            sunSubtendDegrees: Derivations.sunAngularDiameterDegrees(sunDistanceKM: sunKM),
            lunationNumber: events.lunationNumber,
            moonAge: Derivations.moonAge(from: events.lastNewMoon, to: date),
            lastNewMoon: events.lastNewMoon,
            firstQuarter: events.firstQuarter,
            fullMoon: events.fullMoon,
            lastQuarter: events.lastQuarter,
            nextNewMoon: events.nextNewMoon,
            subEarthLatitude: libration.subEarthLatitude,
            subEarthLongitude: libration.subEarthLongitude,
            axisPositionAngleDegrees: axisPositionAngle
        )
    }

    /// The phase events of the lunation containing `date`. Convenience over the
    /// `AstroTime` form so callers needn't depend on AstronomyKit.
    static func lunationEvents(containing date: Date) throws -> LunationEvents {
        try lunationEvents(containing: AstroTime(date))
    }

    /// The phase events of the lunation containing `t`, anchored on the last new
    /// moon. This is the costly part — five iterative `searchPhase` calls — so
    /// callers cache the result for the lunation's duration.
    static func lunationEvents(containing t: AstroTime) throws -> LunationEvents {
        let lastNew = try lastNewMoon(onOrBefore: t)
        let firstQuarter = try Moon.searchPhase(.firstQuarter, after: lastNew)
        let fullMoon = try Moon.searchPhase(.full, after: lastNew)
        let lastQuarter = try Moon.searchPhase(.thirdQuarter, after: lastNew)
        let nextNew = try Moon.searchPhase(.new, after: lastNew.addingDays(1))

        let lunation = Derivations.moonToolLunationNumber(
            newMoonJD: Derivations.julianDate(j2000UTDays: lastNew.universalTime)
        )

        return LunationEvents(
            lastNewMoon: lastNew.date,
            firstQuarter: firstQuarter.date,
            fullMoon: fullMoon.date,
            lastQuarter: lastQuarter.date,
            nextNewMoon: nextNew.date,
            lunationNumber: lunation
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
