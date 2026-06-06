//
//  MoonReadout+Format.swift
//  Gibbous
//
//  Display strings for the readout — kept out of the views so both skins format
//  identically. Local times use the readout's timezone; universal time is UTC.
//

import Foundation

nonisolated extension MoonReadout {
    // MARK: Lunation cache

    /// This readout's lunation events, to reuse on the next tick without
    /// re-running the expensive phase searches (see `AppReducer.tick`).
    var lunationEvents: LunationEvents {
        LunationEvents(
            lastNewMoon: lastNewMoon, firstQuarter: firstQuarter, fullMoon: fullMoon,
            lastQuarter: lastQuarter, nextNewMoon: nextNewMoon, lunationNumber: lunationNumber)
    }

    /// Whether `date` still falls in this readout's lunation, so its cached
    /// events can be reused. A backward jump (e.g. a system clock change) also
    /// fails this and forces a recompute.
    func containsLunation(of date: Date) -> Bool {
        lastNewMoon <= date && date < nextNewMoon
    }

    /// A labelled phase event in the current lunation.
    struct PhaseEvent: Identifiable {
        var id: String { label }
        let label: String
        let date: Date
    }

    var phaseEvents: [PhaseEvent] {
        [
            PhaseEvent(label: "Last New", date: lastNewMoon),
            PhaseEvent(label: "First Quarter", date: firstQuarter),
            PhaseEvent(label: "Full Moon", date: fullMoon),
            PhaseEvent(label: "Last Quarter", date: lastQuarter),
            PhaseEvent(label: "Next New", date: nextNewMoon),
        ]
    }

    // MARK: Numbers

    var julianDateText: String { String(format: "%.5f", julianDate) }
    var lunationText: String { "\(lunationNumber)" }
    var illuminationText: String { String(format: "%.1f%%", illuminatedFraction * 100) }
    var moonAgeText: String { "\(moonAge.days)d \(moonAge.hours)h \(moonAge.minutes)m" }

    var moonDistanceText: String {
        "\(moonDistanceKM.formatted(.number.precision(.fractionLength(0)))) km"
    }
    var moonDistanceEarthRadiiText: String { String(format: "%.1f ER", moonDistanceEarthRadii) }
    var sunDistanceAUText: String { String(format: "%.3f AU", sunDistanceAU) }
    var moonSubtendText: String { String(format: "%.4f°", moonSubtendDegrees) }
    var sunSubtendText: String { String(format: "%.4f°", sunSubtendDegrees) }

    // MARK: Times

    /// The local clock at "now", e.g. "21:58:18".
    var localTimeText: String { string(now, Self.clock) }
    /// Local date at "now", e.g. "5 Oct 2014".
    var localDateText: String { string(now, Self.day) }

    /// Format a phase-event date in the display timezone, e.g. "8 Oct 10:51".
    func eventText(_ date: Date) -> String { string(date, Self.event) }

    // MARK: Formatters
    //
    // Cached once (creating a DateFormatter is expensive); the timezone is
    // applied per call. Formatting runs on the main actor in the views.

    private static let clock = formatter("HH:mm:ss")
    private static let day = formatter("d MMM yyyy")
    private static let event = formatter("d MMM HH:mm")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }
    private func string(_ date: Date, _ formatter: DateFormatter) -> String {
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
