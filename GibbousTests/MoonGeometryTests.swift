//
//  MoonGeometryTests.swift
//  GibbousTests
//
//  The disc terminator geometry: illuminated fraction f = (1 − cos φ)/2 and the
//  waxing/waning side, validated at the four quarter phases.
//

import Testing

@testable import Gibbous

struct MoonGeometryTests {
    @Test func newMoonIsUnlit() {
        #expect(MoonGeometry.illuminatedFraction(phaseAngleDegrees: 0) < 0.001)
    }

    @Test func firstQuarterIsHalfLitAndWaxing() {
        #expect(abs(MoonGeometry.illuminatedFraction(phaseAngleDegrees: 90) - 0.5) < 0.001)
        #expect(MoonGeometry.isWaxing(phaseAngleDegrees: 90))
    }

    @Test func fullMoonIsFullyLit() {
        #expect(MoonGeometry.illuminatedFraction(phaseAngleDegrees: 180) > 0.999)
    }

    @Test func thirdQuarterIsHalfLitAndWaning() {
        #expect(abs(MoonGeometry.illuminatedFraction(phaseAngleDegrees: 270) - 0.5) < 0.001)
        #expect(!MoonGeometry.isWaxing(phaseAngleDegrees: 270))
    }
}
