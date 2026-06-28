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
        #expect(r.illuminationText == "82.1%")
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

    // MARK: Distance (locale measurement system: km vs miles)

    @Test func distanceUsesKilometresInAMetricRegion() {
        let r = SampleReadout.make()
        let german = Locale(identifier: "de_DE")
        let moon = r.distanceText(r.moonDistanceKM, locale: german)
        let sun = r.distanceText(r.sunDistanceKM, locale: german)
        // Grouping separators are locale-dependent, so assert the unit symbol and
        // that the digits round-trip rather than the exact punctuation.
        #expect(moon.contains("km"))
        #expect(sun.contains("km"))
        #expect(moon.filter(\.isNumber) == "362640")
        #expect(sun.filter(\.isNumber) == "149599212")
    }

    @Test func distanceConvertsToMilesInTheUSRegion() {
        let r = SampleReadout.make()
        let us = Locale(identifier: "en_US")
        let moon = r.distanceText(r.moonDistanceKM, locale: us)
        #expect(moon.contains("mi"))
        #expect(!moon.contains("km"))
        // The kilometre figure was actually converted, not just relabelled.
        let miles = Measurement(value: r.moonDistanceKM, unit: UnitLength.kilometers)
            .converted(to: .miles).value
        let shown = Double(moon.filter(\.isNumber)) ?? 0
        #expect(shown != 362_640)
        #expect(abs(shown - miles) < 2)  // displayed value rounds the conversion
    }

    // MARK: Times (timezone applied per call, locale hour cycle)

    @Test func localTimeUsesA24HourClockInABritishRegion() {
        let r = SampleReadout.make()  // GMT
        #expect(r.timeText(r.now, locale: Locale(identifier: "en_GB")) == "21:58:18")
    }

    @Test func localTimeUsesA12HourClockInTheUSRegion() {
        let r = SampleReadout.make()  // GMT
        let text = r.timeText(r.now, locale: Locale(identifier: "en_US"))
        #expect(text.contains("9:58:18"))
        #expect(text.contains("PM"))
        #expect(!text.contains("21:58:18"))
    }

    @Test func localTimeShiftsWithTheTimeZone() throws {
        let eastern = try #require(TimeZone(identifier: "America/New_York"))
        let r = SampleReadout.make(timeZone: eastern)
        // 21:58:18 UTC is 17:58:18 EDT on 2014-10-05; en_GB keeps a 24-hour clock.
        #expect(r.timeText(r.now, locale: Locale(identifier: "en_GB")) == "17:58:18")
    }

    @Test func dateAndEventFollowLocaleFieldOrder() {
        let r = SampleReadout.make()
        let us = Locale(identifier: "en_US")
        let gb = Locale(identifier: "en_GB")
        let date: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()
        let event: Date.FormatStyle = .dateTime.day().month(.abbreviated).hour().minute()
        #expect(r.dateText(r.now, locale: us) == reference(date, r.now, us))
        #expect(r.dateText(r.now, locale: gb) == reference(date, r.now, gb))
        #expect(r.eventText(r.fullMoon, locale: us) == reference(event, r.fullMoon, us))
        #expect(r.eventText(r.fullMoon, locale: gb) == reference(event, r.fullMoon, gb))
        // The two regions order the fields differently (US: "Oct 5, 2014",
        // GB: "5 Oct 2014"), proving the order follows the locale.
        #expect(r.dateText(r.now, locale: us) != r.dateText(r.now, locale: gb))
    }

    private func reference(_ style: Date.FormatStyle, _ date: Date, _ locale: Locale) -> String {
        var s = style
        s.timeZone = .gmt
        s.locale = locale
        return date.formatted(s)
    }

    // MARK: Captions (localized, default English)

    @Test func captionsResolveToTheirEnglishDefaults() {
        let r = SampleReadout.make()
        #expect(String(localized: r.phaseName) == "Waxing Gibbous")
        #expect(String(localized: r.illuminationCaption) == "82.1% illuminated")
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
