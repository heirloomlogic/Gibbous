//
//  MoonReadout+Format.swift
//  Gibbous
//
//  Display strings for the readout — kept out of the views so both skins format
//  identically. Local times use the readout's timezone; universal time is UTC.
//

import Foundation

/// Single source of truth for the readout's static labels and group-box titles.
/// Both skins reference these exact strings, so the Modern and Retro faces can
/// never drift apart on the same label. (Data-derived captions — illumination,
/// Julian Date, phase-event labels — stay computed on `MoonReadout` below.)
enum ReadoutCopy {
    static let phasesTitle = LocalizedStringResource(
        "readout.phasesTitle",
        defaultValue: "Phases of the Moon",
        comment: "Title of the group box listing the dates of this lunation's phase events."
    )
    static let moonAgeTitle = LocalizedStringResource(
        "readout.moonAgeTitle",
        defaultValue: "Moon Age",
        comment: "Title of the group box showing the Moon's age and lunation number (Retro skin)."
    )
    static let subtendTitle = LocalizedStringResource(
        "readout.subtendTitle",
        defaultValue: "Subtend",
        comment: """
            Title of the group box showing the angular diameter (the subtended angle) \
            of the Moon and Sun (Retro skin).
            """
    )
    static let distanceTitle = LocalizedStringResource(
        "readout.distanceTitle",
        defaultValue: "Distance",
        comment: "Title of the group box showing the distance to the Moon and Sun."
    )
    static let timeAndDateTitle = LocalizedStringResource(
        "readout.timeAndDateTitle",
        defaultValue: "Time and Date",
        comment: "Title of the footer group box showing local time, date, and Julian Date."
    )
    static let moon = LocalizedStringResource(
        "readout.moon",
        defaultValue: "Moon",
        comment: "Label for the Moon. Used both as a group-box title (the hero) and as a row label in the Distance box."
    )
    static let sun = LocalizedStringResource(
        "readout.sun",
        defaultValue: "Sun",
        comment: "Row label for the Sun in the Distance box."
    )
    static let age = LocalizedStringResource(
        "readout.age",
        defaultValue: "Age",
        comment: "Row label for the Moon's age in the Moon Age box (Retro skin)."
    )
    static let lunation = LocalizedStringResource(
        "readout.lunation",
        defaultValue: "Lunation",
        comment: "Row label for the lunation (synodic month) number, in both skins."
    )
    static let moonSubtend = LocalizedStringResource(
        "readout.moonSubtend",
        defaultValue: "Moon ∅",
        comment: "Row label: the Moon's angular diameter (Retro skin). ∅ is the diameter symbol."
    )
    static let sunSubtend = LocalizedStringResource(
        "readout.sunSubtend",
        defaultValue: "Sun ∅",
        comment: "Row label: the Sun's angular diameter (Retro skin). ∅ is the diameter symbol."
    )
    static let unavailable = LocalizedStringResource(
        "readout.unavailable",
        defaultValue: "Moon unavailable",
        comment: "Shown in place of the Moon disc when the ephemeris cannot be computed."
    )
}

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

    /// A labelled phase event in the current lunation. `kind` is the stable,
    /// locale-independent identity (so `ForEach` doesn't re-diff when the
    /// localized `label` changes); `label` is the display string.
    struct PhaseEvent: Identifiable {
        enum Kind { case lastNew, firstQuarter, fullMoon, lastQuarter, nextNew }
        let kind: Kind
        let label: LocalizedStringResource
        let date: Date
        var id: Kind { kind }
    }

    var phaseEvents: [PhaseEvent] {
        [
            PhaseEvent(
                kind: .lastNew,
                label: LocalizedStringResource(
                    "phase.event.lastNew", defaultValue: "Last New",
                    comment: "Phase-timeline row: the New Moon that began the current lunation."), date: lastNewMoon),
            PhaseEvent(
                kind: .firstQuarter,
                label: LocalizedStringResource(
                    "phase.event.firstQuarter", defaultValue: "First Quarter",
                    comment: "Phase-timeline row: the First Quarter Moon."), date: firstQuarter),
            PhaseEvent(
                kind: .fullMoon,
                label: LocalizedStringResource(
                    "phase.event.fullMoon", defaultValue: "Full Moon",
                    comment: "Phase-timeline row: the Full Moon."), date: fullMoon),
            PhaseEvent(
                kind: .lastQuarter,
                label: LocalizedStringResource(
                    "phase.event.lastQuarter", defaultValue: "Last Quarter",
                    comment: "Phase-timeline row: the Last Quarter Moon."), date: lastQuarter),
            PhaseEvent(
                kind: .nextNew,
                label: LocalizedStringResource(
                    "phase.event.nextNew", defaultValue: "Next New",
                    comment: "Phase-timeline row: the New Moon that ends the current lunation."), date: nextNewMoon),
        ]
    }

    // MARK: Numbers

    var julianDateText: String { String(format: "%.5f", julianDate) }
    var lunationText: String { "\(lunationNumber)" }
    var illuminationText: String { String(format: "%.1f%%", illuminatedFraction * 100) }
    var moonAgeText: String { "\(moonAge.days)d \(moonAge.hours)h \(moonAge.minutes)m" }

    var moonDistanceText: String { distanceKMText(moonDistanceKM) }
    var sunDistanceText: String { distanceKMText(sunDistanceKM) }
    private func distanceKMText(_ km: Double) -> String {
        "\(km.formatted(.number.precision(.fractionLength(0)))) km"
    }
    var moonDistanceEarthRadiiText: String { String(format: "%.1f ER", moonDistanceEarthRadii) }
    var sunDistanceAUText: String { String(format: "%.3f AU", sunDistanceAU) }
    var moonSubtendText: String { String(format: "%.4f°", moonSubtendDegrees) }
    var sunSubtendText: String { String(format: "%.4f°", sunSubtendDegrees) }

    // MARK: Captions
    //
    // Localized headline strings shared by both skins, so the key, wording, and
    // translator comment live in exactly one place.

    /// The hero headline: the Moon's current *visual* phase, e.g. "Waxing
    /// Gibbous". Derived from the illuminated fraction and waxing direction (see
    /// `MoonPhaseDescriptor`), not AstronomyKit's equal-band label — so a Moon
    /// that is more than half lit reads "Gibbous", as the eye sees it. The
    /// principal phases stay the dated *events* in the phase timeline above
    /// (`phaseEvents`); this names the disc's present shape.
    var phaseName: LocalizedStringResource {
        switch MoonPhaseDescriptor.current(illuminatedFraction: illuminatedFraction, isWaxing: isWaxing) {
        case .newMoon:
            return LocalizedStringResource(
                "phase.name.newMoon", defaultValue: "New Moon",
                comment: "Hero headline: current phase when the disc is essentially unlit.")
        case .waxingCrescent:
            return LocalizedStringResource(
                "phase.name.waxingCrescent", defaultValue: "Waxing Crescent",
                comment: "Hero headline: current phase, less than half lit and growing.")
        case .firstQuarter:
            return LocalizedStringResource(
                "phase.name.firstQuarter", defaultValue: "First Quarter",
                comment: "Hero headline: current phase, about half lit and growing.")
        case .waxingGibbous:
            return LocalizedStringResource(
                "phase.name.waxingGibbous", defaultValue: "Waxing Gibbous",
                comment: "Hero headline: current phase, more than half lit and growing.")
        case .fullMoon:
            return LocalizedStringResource(
                "phase.name.fullMoon", defaultValue: "Full Moon",
                comment: "Hero headline: current phase when the disc is essentially fully lit.")
        case .waningGibbous:
            return LocalizedStringResource(
                "phase.name.waningGibbous", defaultValue: "Waning Gibbous",
                comment: "Hero headline: current phase, more than half lit and shrinking.")
        case .lastQuarter:
            return LocalizedStringResource(
                "phase.name.lastQuarter", defaultValue: "Last Quarter",
                comment: "Hero headline: current phase, about half lit and shrinking.")
        case .waningCrescent:
            return LocalizedStringResource(
                "phase.name.waningCrescent", defaultValue: "Waning Crescent",
                comment: "Hero headline: current phase, less than half lit and shrinking.")
        }
    }

    /// The caption under the phase name, e.g. "82.1% illuminated".
    var illuminationCaption: LocalizedStringResource {
        LocalizedStringResource(
            "moon.illumination",
            defaultValue: "\(illuminationText) illuminated",
            comment: """
                Caption under the phase name: the share of the Moon's disc currently \
                lit, e.g. "63.2% illuminated". %@ is the already-formatted percentage.
                """)
    }

    /// The Julian Date readout for the Time-and-Date footer, e.g. "JD 2461211.16344".
    var julianDateCaption: LocalizedStringResource {
        LocalizedStringResource(
            "readout.julianDate.short",
            defaultValue: "JD \(julianDateText)",
            comment: """
                Julian Date readout in the Time and Date footer. "JD" is the standard \
                abbreviation for Julian Date; %@ is the numeric value.
                """)
    }

    // MARK: Times

    /// The local clock at "now", e.g. "21:58:18".
    @MainActor var localTimeText: String { string(now, Self.clock) }
    /// Local date at "now", e.g. "5 Oct 2014".
    @MainActor var localDateText: String { string(now, Self.day) }

    /// Format a phase-event date in the display timezone, e.g. "8 Oct 10:51".
    @MainActor func eventText(_ date: Date) -> String { string(date, Self.event) }

    // MARK: Formatters
    //
    // Cached once (creating a DateFormatter is expensive); the timezone is
    // applied per call. `DateFormatter` is not thread-safe and the per-call
    // timezone mutation makes the shared instances mutable state, so the
    // formatting members are MainActor-isolated — every caller is a view.

    @MainActor private static let clock = formatter("HH:mm:ss")
    @MainActor private static let day = formatter("d MMM yyyy")
    @MainActor private static let event = formatter("d MMM HH:mm")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }
    @MainActor private func string(_ date: Date, _ formatter: DateFormatter) -> String {
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
