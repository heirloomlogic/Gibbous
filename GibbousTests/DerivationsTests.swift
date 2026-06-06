//
//  DerivationsTests.swift
//  GibbousTests
//
//  Pure-function unit tests for the client-side derivations (Julian Date,
//  angular diameters, unit conversions, Brown lunation number, Moon age).
//  These need no ephemeris — they assert the formulas in isolation against
//  the Moon Tool golden master (see MoonAlmanacGoldenTests for the live run).
//

import Foundation
import Testing

@testable import Gibbous

struct DerivationsTests {
    // MARK: Julian Date

    @Test func julianDateAtJ2000EpochIsTheEpochConstant() {
        // universalTime is days since J2000 noon (JD 2451545.0).
        #expect(Derivations.julianDate(j2000UTDays: 0) == 2_451_545.0)
    }

    @Test func julianDateAddsDaysOntoTheEpoch() {
        #expect(abs(Derivations.julianDate(j2000UTDays: 100.5) - 2_451_645.5) < 1e-9)
    }

    // MARK: Angular diameters

    @Test func sunSubtendsAboutHalfADegreeAtOneAU() {
        let deg = Derivations.sunAngularDiameterDegrees(sunDistanceKM: Derivations.auKM)
        #expect(abs(deg - 0.5333) < 0.002)
    }

    // MARK: Unit conversions

    @Test func moonDistanceConvertsKilometresToEarthRadii() {
        // Golden master: 363898 km ≈ 57.1 Earth radii.
        #expect(abs(Derivations.moonDistanceEarthRadii(km: 363_898) - 57.1) < 0.1)
    }

    @Test func sunDistanceConvertsAUToKilometres() {
        #expect(abs(Derivations.sunDistanceKM(au: 1.0) - 149_597_870.7) < 1e-6)
    }

    // MARK: Brown lunation number

    @Test func brownLunationNumberMatchesStandardForSept2014NewMoon() {
        // New moon of 2014-09-24 ≈ JD 2456924.76. Standard BLN = 1135.
        #expect(Derivations.brownLunationNumber(newMoonJD: 2_456_924.76) == 1135)
    }

    @Test func moonToolLunationAddsOneToStandard() {
        // Moon Tool's display shows 1136 for that lunation (standard + 1).
        #expect(Derivations.moonToolLunationNumber(newMoonJD: 2_456_924.76) == 1136)
    }

    // MARK: Moon age

    @Test func moonAgeDecomposesIntervalIntoDaysHoursMinutes() {
        let newMoon = Date(timeIntervalSinceReferenceDate: 0)
        let interval: TimeInterval = (11 * 86_400) + (13 * 3_600) + (44 * 60)
        let age = Derivations.moonAge(from: newMoon, to: newMoon.addingTimeInterval(interval))
        #expect(age == MoonAge(days: 11, hours: 13, minutes: 44))
    }
}
