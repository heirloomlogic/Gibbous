//
//  MoonAlmanacGoldenTests.swift
//  GibbousTests
//
//  Golden master: the Moon Tool reference screenshot captured at
//  2014-10-05T21:58:18Z. The timezone-independent ephemeris scalars assert
//  tightly; the phase-event timeline asserts ordering plus the well-known
//  2014-10-08 full moon (the total lunar eclipse). See the MoonHomage plan.
//

import Foundation
import Testing

@testable import Gibbous

// `.serialized` so the suite is deterministic regardless of the runner's
// parallelism (the underlying ephemeris C library is shared).
@Suite(.serialized) struct MoonAlmanacGoldenTests {
    // Calibration note (verified 2026-06-03 against AstronomyKit @ main):
    // AstronomyKit is the modern, JPL-validated ephemeris and its output here
    // is internally self-consistent. The Moon Tool reference screenshot is the
    // 1988-era program's lower-precision output, so a few fields differ — that
    // gap *is* Gibbous's premise ("rebuilt on accurate ephemeris"). We assert
    // AstronomyKit's accurate values and document each screenshot delta:
    //  • JD: screenshot prints 2456936.91549, which is exactly +0.5 day off the
    //    true JD of the stated instant (2456936.41549) — a noon/midnight
    //    transcription slip in the reference, not an ephemeris difference.
    //  • Moon distance: screenshot 363898 km vs accurate 362640 km (~0.35%);
    //    our subtend is correspondingly larger (closer Moon ⇒ bigger disc).
    //  • Moon age: screenshot 11d13h44m vs accurate 11d15h43m (~2h) — Moon
    //    Tool's coarser new-moon time.
    // Lunation (1136), the Oct-8-2014 eclipse full moon, sun distance and
    // subtends all match the screenshot and corroborate the pipeline.

    /// 2014-10-05 21:58:18 UTC — the reference screenshot instant.
    static let instant = Date(timeIntervalSince1970: 1_412_546_298)
    static let nz = TimeZone(identifier: "Pacific/Auckland") ?? .gmt

    func readout() throws -> MoonReadout {
        try MoonAlmanac.readout(at: Self.instant, timeZone: Self.nz)
    }

    @Test func julianDateIsCorrectForTheInstant() throws {
        // True JD of 2014-10-05 21:58:18 UTC (verified by hand). The reference
        // screenshot's 2456936.91549 is +0.5 day off — see calibration note.
        #expect(abs(try readout().julianDate - 2_456_936.41549) < 1e-4)
    }

    @Test func moonDistanceMatchesAccurateEphemeris() throws {
        let r = try readout()
        // Accurate value 362640 km (screenshot showed Moon Tool's 363898).
        #expect(abs(r.moonDistanceKM - 362_640) < 50)
        #expect(abs(r.moonDistanceEarthRadii - 56.857) < 0.02)
    }

    @Test func sunDistanceMatchesScreenshot() throws {
        let r = try readout()
        #expect(abs(r.sunDistanceAU - 1.000) < 0.0005)
        #expect(abs(r.sunDistanceKM - 149_599_212) < 100_000)
    }

    @Test func subtendsMatchScreenshot() throws {
        let r = try readout()
        #expect(abs(r.moonSubtendDegrees - 0.5473) < 0.003)
        #expect(abs(r.sunSubtendDegrees - 0.5333) < 0.003)
    }

    @Test func lunationNumberMatchesScreenshot() throws {
        #expect(try readout().lunationNumber == 1136)
    }

    @Test func moonAgeMatchesAccurateEphemeris() throws {
        // Accurate age 11d 15h 43m from the Sep-24 06:14 UTC new moon
        // (screenshot showed Moon Tool's 11d 13h 44m — see calibration note).
        let age = try readout().moonAge
        #expect(age.days == 11)
        #expect(age.hours == 15)
        #expect(abs(age.minutes - 43) <= 1)
    }

    @Test func phaseEventsAreOrderedAroundNow() throws {
        let r = try readout()
        #expect(r.lastNewMoon < r.firstQuarter)
        #expect(r.firstQuarter < Self.instant)
        #expect(Self.instant < r.fullMoon)
        #expect(r.fullMoon < r.lastQuarter)
        #expect(r.lastQuarter < r.nextNewMoon)
    }

    @Test func fullMoonIsTheOctober8EclipseMoon() throws {
        let full = try readout().fullMoon
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        let c = cal.dateComponents([.year, .month, .day], from: full)
        #expect(c.year == 2014 && c.month == 10 && c.day == 8)
    }

    // MARK: Lunation-event caching (the split is behavior-preserving)

    @Test func lunationEventsMatchTheReadoutTimeline() throws {
        let events = try MoonAlmanac.lunationEvents(containing: Self.instant)
        let r = try readout()
        #expect(events.lastNewMoon == r.lastNewMoon)
        #expect(events.firstQuarter == r.firstQuarter)
        #expect(events.fullMoon == r.fullMoon)
        #expect(events.lastQuarter == r.lastQuarter)
        #expect(events.nextNewMoon == r.nextNewMoon)
        #expect(events.lunationNumber == r.lunationNumber)
        // "now" is inside the lunation, so these events are reusable.
        #expect(r.containsLunation(of: Self.instant))
        #expect(r.lunationEvents == events)
    }

    @Test func readoutWithReusedEventsEqualsFreshReadout() throws {
        // A later instant in the same lunation: reusing the cached events must
        // produce the same readout as recomputing from scratch.
        let later = Self.instant.addingTimeInterval(3_600)
        let events = try MoonAlmanac.lunationEvents(containing: Self.instant)
        let reused = try MoonAlmanac.readout(at: later, timeZone: Self.nz, events: events)
        let fresh = try MoonAlmanac.readout(at: later, timeZone: Self.nz)
        #expect(reused == fresh)
    }
}
