//
//  MoonPhaseDescriptorTests.swift
//  GibbousTests
//
//  The visual phase-naming thresholds: New/Full occupy a couple of days near 0%
//  and 100%, the Quarters a ~day-wide window around half-lit, and crescent vs.
//  gibbous split at the 45%/55% edges. The headline case the whole change exists
//  for: a 56%-lit waxing Moon reads "Waxing Gibbous", not "First Quarter".
//

import Testing

@testable import Gibbous

struct MoonPhaseDescriptorTests {
    @Test func aMoreThanHalfLitWaxingMoonIsGibbousNotFirstQuarter() {
        // The motivating bug: AstronomyKit's equal bands called this "First
        // Quarter"; by illumination it is plainly gibbous.
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.56, isWaxing: true) == .waxingGibbous)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.56, isWaxing: false) == .waningGibbous)
    }

    @Test func halfLitIsAQuarter() {
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.5, isWaxing: true) == .firstQuarter)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.5, isWaxing: false) == .lastQuarter)
    }

    @Test func theQuarterWindowSpans45To55Percent() {
        // Inclusive edges read as a Quarter; just outside flips to crescent/gibbous.
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.45, isWaxing: true) == .firstQuarter)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.55, isWaxing: true) == .firstQuarter)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.44, isWaxing: true) == .waxingCrescent)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.56, isWaxing: true) == .waxingGibbous)
    }

    @Test func crescentsAreLessThanHalfLit() {
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.20, isWaxing: true) == .waxingCrescent)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.20, isWaxing: false) == .waningCrescent)
    }

    @Test func gibbousesAreMoreThanHalfLit() {
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.80, isWaxing: true) == .waxingGibbous)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.80, isWaxing: false) == .waningGibbous)
    }

    @Test func nearFullReadsFullRegardlessOfDirection() {
        // Full persists for ~2 days: anything ≥ 98% lit, waxing or waning.
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.98, isWaxing: true) == .fullMoon)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.99, isWaxing: false) == .fullMoon)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 1.0, isWaxing: false) == .fullMoon)
    }

    @Test func nearNewReadsNewRegardlessOfDirection() {
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.0, isWaxing: true) == .newMoon)
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.019, isWaxing: false) == .newMoon)
    }

    @Test func justPastNewIsAlreadyACrescent() {
        #expect(MoonPhaseDescriptor.current(illuminatedFraction: 0.05, isWaxing: true) == .waxingCrescent)
    }
}
