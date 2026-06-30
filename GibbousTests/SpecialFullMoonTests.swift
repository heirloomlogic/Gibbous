//
//  SpecialFullMoonTests.swift
//  GibbousTests
//
//  Golden master for the formally-definable special full moons. The classifier
//  is asserted against well-known 2023 full moons (the year of the famous Aug-31
//  "blue supermoon"); the headline and priority logic are asserted directly.
//

import Foundation
import Testing

@testable import Gibbous

@Suite(.serialized) struct SpecialFullMoonTests {
    /// Noon UTC on the given day — a point safely inside the target lunation, so
    /// `lunationEvents(containing:)` resolves to that month's full moon.
    private static func utc(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: components) else {
            preconditionFailure("invalid UTC date components: \(year)-\(month)-\(day)")
        }
        return date
    }

    private static func classify(_ date: Date, timeZone: TimeZone = .gmt) throws -> SpecialFullMoonKind? {
        try MoonAlmanac.lunationEvents(containing: date, timeZone: timeZone).specialFullMoon
    }

    // MARK: Classification against known 2023 full moons

    @Test func augustThirtyFirstIsABlueMoon() throws {
        // 2023-08-31 was the second full moon of August *and* the year's closest
        // (a supermoon). Blue outranks Supermoon, so the headline is Blue.
        #expect(try Self.classify(Self.utc(2023, 9, 1)) == .blueMoon)
    }

    @Test func augustFirstIsAPlainSupermoon() throws {
        // The first full moon of August: a supermoon, but not blue (the previous
        // full moon was in July) and not autumnal.
        #expect(try Self.classify(Self.utc(2023, 8, 2)) == .supermoon)
    }

    @Test func septemberTwentyNinthIsTheHarvestMoon() throws {
        // The full moon nearest the 2023-09-23 September equinox.
        #expect(try Self.classify(Self.utc(2023, 9, 30)) == .harvestMoon)
    }

    @Test func octoberTwentyEighthIsTheHuntersMoon() throws {
        // The full moon immediately after the Harvest moon.
        #expect(try Self.classify(Self.utc(2023, 10, 29)) == .huntersMoon)
    }

    @Test func februaryFifthIsAnOrdinaryFullMoon() throws {
        // 2023's micromoon (near apogee): far from perigee, single full moon in
        // its month, not autumnal — none of the special names apply.
        #expect(try Self.classify(Self.utc(2023, 2, 6)) == nil)
    }

    // MARK: Priority

    @Test func mostNotablePicksByDeclarationOrder() {
        #expect(SpecialFullMoonKind.mostNotable(in: [.supermoon, .blueMoon]) == .blueMoon)
        #expect(SpecialFullMoonKind.mostNotable(in: [.huntersMoon, .supermoon]) == .huntersMoon)
        #expect(SpecialFullMoonKind.mostNotable(in: [.supermoon]) == .supermoon)
        #expect(SpecialFullMoonKind.mostNotable(in: []) == nil)
    }

    // MARK: Names

    @Test func namesResolveToEnglishDefaults() {
        #expect(String(localized: SpecialFullMoonKind.blueMoon.name) == "Blue Moon")
        #expect(String(localized: SpecialFullMoonKind.harvestMoon.name) == "Harvest Moon")
        #expect(String(localized: SpecialFullMoonKind.huntersMoon.name) == "Hunter's Moon")
        #expect(String(localized: SpecialFullMoonKind.supermoon.name) == "Supermoon")
    }

    // MARK: Headline gating

    @Test func headlineAppendsQualifierWhenFull() {
        var readout = SampleReadout.make()
        readout.illuminatedFraction = 0.99  // reads as Full
        readout.specialFullMoon = .blueMoon
        #expect(String(localized: readout.phaseHeadline) == "Full Moon (Blue Moon)")
    }

    @Test func headlineHidesQualifierWhenNotFull() {
        // The sample is a waxing gibbous (82% lit): the qualifier is suppressed
        // even though the lunation classifies, so it shows only at the full disc.
        var readout = SampleReadout.make()
        readout.specialFullMoon = .blueMoon
        #expect(String(localized: readout.phaseHeadline) == String(localized: readout.phaseName))
        #expect(String(localized: readout.phaseHeadline) == "Waxing Gibbous")
    }

    @Test func headlineEqualsPhaseNameWhenNoSpecialMoon() {
        var readout = SampleReadout.make()
        readout.illuminatedFraction = 0.99
        readout.specialFullMoon = nil
        #expect(String(localized: readout.phaseHeadline) == "Full Moon")
    }
}
