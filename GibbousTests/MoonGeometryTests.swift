//
//  MoonGeometryTests.swift
//  GibbousTests
//
//  The disc terminator geometry: illuminated fraction f = (1 − cos φ)/2 and the
//  waxing/waning side, validated at the four quarter phases.
//

import Testing
import simd

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

    // MARK: Axis position angle (disc roll)

    /// With the Moon on the +x axis, the sky-plane basis is east = +y, north =
    /// +z (see `axisPositionAngleDegrees`). A pole pointing at celestial north
    /// projects straight "up", so the roll is zero.
    @Test func poleAtCelestialNorthGivesZeroRoll() {
        let pa = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(1, 0, 0), northPole: SIMD3(0, 0, 1))
        #expect(abs(pa) < 1e-9)
    }

    /// A pole leaning toward east (the +y sky direction) reads as +90°.
    @Test func poleTowardEastGivesNinetyDegrees() {
        let pa = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(1, 0, 0), northPole: SIMD3(0, 1, 0))
        #expect(abs(pa - 90) < 1e-9)
    }

    /// A pole leaning toward celestial south reads as ±180°.
    @Test func poleTowardSouthGivesStraightDown() {
        let pa = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(1, 0, 0), northPole: SIMD3(0, 0, -1))
        #expect(abs(abs(pa) - 180) < 1e-9)
    }

    /// The component of the pole along the line of sight doesn't affect the
    /// projected roll — only the sky-plane lean does.
    @Test func lineOfSightComponentIgnored() {
        let onSky = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(1, 0, 0), northPole: SIMD3(0, 0.5, 0.5))
        let withDepth = MoonGeometry.axisPositionAngleDegrees(
            moonDirection: SIMD3(1, 0, 0), northPole: SIMD3(0.8, 0.5, 0.5))
        #expect(abs(onSky - withDepth) < 1e-9)
    }
}
