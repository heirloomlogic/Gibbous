//
//  Derivations.swift
//  Gibbous
//
//  Client-side derivations Moon Tool displays but AstronomyKit doesn't hand
//  back directly: Julian Date, the Sun's angular diameter, unit conversions,
//  the Brown lunation number, and the Moon's age. Pure functions — no
//  ephemeris — so they're unit-testable in isolation against the golden master.
//

import Foundation

/// The Moon's age within the current lunation, decomposed for display.
nonisolated struct MoonAge: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int
}

nonisolated enum Derivations {
    /// Mean equatorial radius of the Earth (km).
    static let earthRadiusKM = 6_378.137
    /// One astronomical unit (km).
    static let auKM = 149_597_870.7
    /// The Sun's radius (km).
    static let solarRadiusKM = 696_000.0
    /// Mean synodic month (days).
    static let synodicMonth = 29.530_588_861
    /// Julian Date of the J2000.0 epoch (2000-01-01 12:00 TT).
    static let j2000JD = 2_451_545.0

    /// Julian Date from AstronomyKit's Universal Time, expressed as days since
    /// J2000 noon. `AstroTime.universalTime` is exactly that offset.
    static func julianDate(j2000UTDays ut: Double) -> Double {
        ut + j2000JD
    }

    /// The Sun's apparent angular diameter (degrees) at a given distance.
    /// `2·atan(r / d)`, converted to degrees.
    static func sunAngularDiameterDegrees(sunDistanceKM: Double) -> Double {
        2 * atan(solarRadiusKM / sunDistanceKM) * 180 / .pi
    }

    /// Moon distance in Earth radii.
    static func moonDistanceEarthRadii(km: Double) -> Double {
        km / earthRadiusKM
    }

    /// Sun distance in kilometres from astronomical units.
    static func sunDistanceKM(au: Double) -> Double {
        au * auKM
    }

    /// Standard Brown lunation number for the new moon at the given Julian Date.
    /// `round((JD − 2451550.09766) / synodic) + 953`.
    static func brownLunationNumber(newMoonJD: Double) -> Int {
        Int(((newMoonJD - 2_451_550.097_66) / synodicMonth).rounded()) + 953
    }

    /// Moon Tool's displayed lunation number — the standard number + 1, to
    /// stay faithful to the original program's convention.
    static func moonToolLunationNumber(newMoonJD: Double) -> Int {
        brownLunationNumber(newMoonJD: newMoonJD) + 1
    }

    /// Decompose the interval between the last new moon and now into d/h/m.
    static func moonAge(from newMoon: Date, to now: Date) -> MoonAge {
        let total = max(0, now.timeIntervalSince(newMoon))
        let days = Int(total / 86_400)
        let afterDays = total - Double(days) * 86_400
        let hours = Int(afterDays / 3_600)
        let afterHours = afterDays - Double(hours) * 3_600
        let minutes = Int(afterHours / 60)
        return MoonAge(days: days, hours: hours, minutes: minutes)
    }
}
