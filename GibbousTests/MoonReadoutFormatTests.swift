//
//  MoonReadoutFormatTests.swift
//  GibbousTests
//
//  The display-string layer: the locale-independent number formats, the
//  timezone-applied time/date strings, the phase-event timeline, and the
//  lunation cache (events + containment window). Both skins render these exact
//  strings, so they're asserted once here rather than through the views.
//

import Foundation
import Testing

@testable import Gibbous

struct MoonReadoutFormatTests {
    // MARK: Numbers (C-locale `String(format:)` — locale-independent)

    @Test func numberFormatsMatchTheReadout() {
        let r = SampleReadout.make()
        #expect(r.julianDateText == "2456936.41549")
        #expect(r.lunationText == "1136")
        #expect(r.illuminationText == "26.8%")
        #expect(r.moonAgeText == "11d 13h 44m")
        #expect(r.moonDistanceEarthRadiiText == "56.9 ER")
        #expect(r.sunDistanceAUText == "1.000 AU")
        #expect(r.moonSubtendText == "0.5473°")
        #expect(r.sunSubtendText == "0.5333°")
    }

    @Test func illuminationFormatsToOneDecimalPercent() {
        var r = SampleReadout.make()
        r.illuminatedFraction = 0.5
        #expect(r.illuminationText == "50.0%")
        r.illuminatedFraction = 1
        #expect(r.illuminationText == "100.0%")
        r.illuminatedFraction = 0
        #expect(r.illuminationText == "0.0%")
    }

    @Test func distanceTextCarriesTheKilometreUnitAndDigits() {
        let r = SampleReadout.make()
        // Grouping separators are locale-dependent, so assert the unit suffix
        // and that the digits round-trip rather than the exact punctuation.
        #expect(r.moonDistanceText.hasSuffix(" km"))
        #expect(r.sunDistanceText.hasSuffix(" km"))
        #expect(r.moonDistanceText.filter(\.isNumber) == "362640")
        #expect(r.sunDistanceText.filter(\.isNumber) == "149599212")
    }

    // MARK: Times (timezone applied per call)

    @MainActor @Test func localTimeUsesTheReadoutTimeZone() {
        let r = SampleReadout.make()  // GMT
        #expect(r.localTimeText == "21:58:18")
    }

    @MainActor @Test func localTimeShiftsWithTheTimeZone() throws {
        let eastern = try #require(TimeZone(identifier: "America/New_York"))
        let r = SampleReadout.make(timeZone: eastern)
        // 21:58:18 UTC is 17:58:18 EDT on 2014-10-05.
        #expect(r.localTimeText == "17:58:18")
    }

    @MainActor @Test func dateAndEventTextMatchAReferenceFormatter() {
        let r = SampleReadout.make()
        #expect(r.localDateText == reference("d MMM yyyy", r.now))
        #expect(r.eventText(r.fullMoon) == reference("d MMM HH:mm", r.fullMoon))
        // Sanity: the date string is not the time string (distinct formatters).
        #expect(r.localDateText != r.localTimeText)
    }

    private func reference(_ format: String, _ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        f.timeZone = .gmt
        return f.string(from: date)
    }

    // MARK: Captions (localized, default English)

    @Test func captionsResolveToTheirEnglishDefaults() {
        let r = SampleReadout.make()
        #expect(String(localized: r.illuminationCaption) == "26.8% illuminated")
        #expect(String(localized: r.julianDateCaption) == "JD 2456936.41549")
    }

    // MARK: Phase-event timeline

    @Test func phaseEventsAreTheFiveLunationMarkersInOrder() {
        let r = SampleReadout.make()
        let events = r.phaseEvents
        #expect(events.map(\.kind) == [.lastNew, .firstQuarter, .fullMoon, .lastQuarter, .nextNew])
        #expect(events.map(\.date) == [r.lastNewMoon, r.firstQuarter, r.fullMoon, r.lastQuarter, r.nextNewMoon])
        // `id` is the locale-independent kind, so ForEach is stable across locales.
        #expect(events.map(\.id) == events.map(\.kind))
    }

    // MARK: Lunation cache

    @Test func lunationEventsMirrorTheReadoutFields() {
        let r = SampleReadout.make()
        let events = r.lunationEvents
        #expect(events.lastNewMoon == r.lastNewMoon)
        #expect(events.firstQuarter == r.firstQuarter)
        #expect(events.fullMoon == r.fullMoon)
        #expect(events.lastQuarter == r.lastQuarter)
        #expect(events.nextNewMoon == r.nextNewMoon)
        #expect(events.lunationNumber == r.lunationNumber)
    }

    @Test func containsLunationIsHalfOpenAroundTheNewMoons() {
        let r = SampleReadout.make()
        #expect(r.containsLunation(of: r.now))  // now sits inside
        #expect(r.containsLunation(of: r.lastNewMoon))  // inclusive lower bound
        #expect(!r.containsLunation(of: r.nextNewMoon))  // exclusive upper bound
        #expect(!r.containsLunation(of: r.lastNewMoon.addingTimeInterval(-1)))  // before
        #expect(!r.containsLunation(of: r.nextNewMoon.addingTimeInterval(1)))  // after
    }
}
