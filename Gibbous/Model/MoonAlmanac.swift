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
    /// The full moon's formal special-moon name, if any (blue / harvest / hunter /
    /// super). Computed once with the events and reused for the lunation's life,
    /// since — like the events — it's fixed for the whole lunation.
    let specialFullMoon: SpecialFullMoonKind?
}

nonisolated enum MoonAlmanac {
    /// Fresh readout for an instant — computes the lunation events too. Used by
    /// tests and any caller without a cached lunation to reuse.
    static func readout(at date: Date, timeZone: TimeZone) throws -> MoonReadout {
        try readout(at: date, timeZone: timeZone, events: lunationEvents(containing: date, timeZone: timeZone))
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
            axisPositionAngleDegrees: axisPositionAngle,
            specialFullMoon: events.specialFullMoon
        )
    }

    /// The phase events of the lunation containing `date`. Convenience over the
    /// `AstroTime` form so callers needn't depend on AstronomyKit. `timeZone` is
    /// the display zone — it only affects the blue-moon test (whether two full
    /// moons share a calendar month depends on the zone the calendar is read in).
    static func lunationEvents(containing date: Date, timeZone: TimeZone) throws -> LunationEvents {
        try lunationEvents(containing: AstroTime(date), timeZone: timeZone)
    }

    /// The phase events of the lunation containing `t`, anchored on the last new
    /// moon. This is the costly part — five iterative `searchPhase` calls plus the
    /// special-moon classification — so callers cache the result for the
    /// lunation's duration.
    static func lunationEvents(containing t: AstroTime, timeZone: TimeZone) throws -> LunationEvents {
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
            lunationNumber: lunation,
            specialFullMoon: try classifySpecialFullMoon(fullMoon: fullMoon, timeZone: timeZone)
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

    // MARK: Special full moons

    /// Earth–Moon distance (km) at or below which a full moon counts as a
    /// supermoon. There is no official cutoff; 360,000 km is the widely-used
    /// convention (timeanddate.com, Espenak). The alternative "within 90% of this
    /// orbit's perigee" rule lands close to the same place.
    static let supermoonCeilingKM = 360_000.0

    /// Classify `fullMoon` against the formally definable special-moon names,
    /// returning the most notable that applies (see `SpecialFullMoonKind`). All
    /// three tests are geocentric/calendar-based — no observer location needed.
    static func classifySpecialFullMoon(
        fullMoon: AstroTime, timeZone: TimeZone
    ) throws -> SpecialFullMoonKind? {
        var kinds: [SpecialFullMoonKind] = []

        // Supermoon: the disc is closest (and largest) at the full-moon instant,
        // so the distance must be read there, not at "now".
        if Moon.libration(at: fullMoon).distanceKM < supermoonCeilingKM {
            kinds.append(.supermoon)
        }

        // Blue moon (monthly definition): an earlier full moon falls in the same
        // calendar month. The previous full moon is the first one after ~40 days
        // back (full moons are ~29.5 days apart). Month boundaries are read in the
        // display zone — that's what makes this timezone-dependent.
        let previousFull = try Moon.searchPhase(.full, after: fullMoon.addingDays(-40))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(previousFull.date, equalTo: fullMoon.date, toGranularity: .month) {
            kinds.append(.blueMoon)
        }

        if let autumn = try harvestOrHunters(fullMoon: fullMoon) {
            kinds.append(autumn)
        }

        return SpecialFullMoonKind.mostNotable(in: kinds)
    }

    /// Whether `fullMoon` is the Harvest moon (nearest the September equinox) or
    /// the Hunter's moon (the next one after it), else `nil`. Both fall Sep–Nov,
    /// so the full moon shares the calendar year of its defining equinox.
    private static func harvestOrHunters(fullMoon: AstroTime) throws -> SpecialFullMoonKind? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let components = utc.dateComponents([.year, .month], from: fullMoon.date)

        // The Harvest moon never falls before September and the Hunter's never
        // after November, so most of the year skips the equinox search entirely.
        guard let year = components.year, let month = components.month,
            (9...11).contains(month)
        else { return nil }
        let equinox = try Seasons.forYear(year).septemberEquinox

        // The full moon nearest the equinox is the Harvest moon. A 30-day lookback
        // window always straddles the equinox (the period is < 30 days), so the
        // nearer of the bracketing full moons is the answer.
        let before = try Moon.searchPhase(.full, after: equinox.addingDays(-30))
        let after = try Moon.searchPhase(.full, after: equinox)
        let distanceBefore = abs(before.date.timeIntervalSince(equinox.date))
        let distanceAfter = abs(after.date.timeIntervalSince(equinox.date))
        let harvest = distanceBefore <= distanceAfter ? before : after

        if isSameFullMoon(fullMoon, harvest) { return .harvestMoon }
        if isSameFullMoon(fullMoon, try Moon.searchPhase(.full, after: harvest.addingDays(1))) {
            return .huntersMoon
        }
        return nil
    }

    /// Whether two phase-search results name the same full moon. Consecutive full
    /// moons are ~29.5 days apart, so a one-hour tolerance is unambiguous while
    /// absorbing any root-finder jitter between two searches for the same event.
    private static func isSameFullMoon(_ a: AstroTime, _ b: AstroTime) -> Bool {
        abs(a.date.timeIntervalSince(b.date)) < 3_600
    }
}
