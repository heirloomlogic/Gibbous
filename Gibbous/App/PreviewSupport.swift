//
//  PreviewSupport.swift
//  Gibbous
//
//  DEBUG-only fixtures for SwiftUI previews: a fixed sample readout and a store
//  preconfigured with stub effects, so the canvas renders the real view tree
//  without touching live preferences or running the ephemeris.
//

#if DEBUG
import Foundation

extension MoonReadout {
    /// Canonical waxing-gibbous sample — self-consistent, hand-set values with
    /// no ephemeris required. The single source of truth for both the preview
    /// store and the formatting tests (which pin exact strings derived from
    /// these numbers), so they can't drift apart. Parameterized on the instant
    /// and timezone the caller wants to render in.
    nonisolated static func sample(
        now: Date = Date(timeIntervalSince1970: 1_412_546_298),  // 2014-10-05 21:58:18 UTC
        timeZone: TimeZone = .gmt
    ) -> MoonReadout {
        let lastNew = Date(timeIntervalSince1970: 1_411_540_440)  // 2014-09-24 06:14 UTC
        return MoonReadout(
            now: now,
            timeZone: timeZone,
            phaseAngleDegrees: 130,
            illuminatedFraction: 0.8214,  // consistent with the 130° gibbous disc
            isWaxing: true,
            julianDate: 2_456_936.415_49,
            moonDistanceKM: 362_640,
            moonDistanceEarthRadii: 56.857,
            sunDistanceAU: 1.0,
            sunDistanceKM: 149_599_212,
            moonSubtendDegrees: 0.5473,
            sunSubtendDegrees: 0.5333,
            lunationNumber: 1136,
            moonAge: MoonAge(days: 11, hours: 13, minutes: 44),
            lastNewMoon: lastNew,
            firstQuarter: lastNew.addingTimeInterval(7.4 * 86_400),
            fullMoon: lastNew.addingTimeInterval(14.0 * 86_400),
            lastQuarter: lastNew.addingTimeInterval(21.5 * 86_400),
            nextNewMoon: lastNew.addingTimeInterval(29.53 * 86_400),
            subEarthLatitude: -2.0,
            subEarthLongitude: 3.0,
            axisPositionAngleDegrees: 18)
    }

    /// The sample rendered in the local timezone, for SwiftUI previews.
    nonisolated static let preview = sample(timeZone: .current)
}

extension AppStore {
    /// A store for previews: a given skin, an optional readout (pass `nil` for
    /// the "ephemeris unavailable" state), and an optional flip to the settings
    /// face. Effects are stubbed and preferences are in-memory.
    @MainActor static func preview(
        style: DisplayStyle = .modern,
        readout: MoonReadout? = .preview,
        showingSettings: Bool = false
    ) -> AppStore {
        let store = AppStore.configured(
            environment: AppEnvironment(
                keyValue: InMemoryKeyValueStore(),
                timeZone: .current,
                now: { Date() },
                computeReadout: { _, _, _ in .preview },
                playHowl: {},
                playHoot: {},
                setLoginItemEnabled: { _ in },
                loginItemEnabled: { false }
            ))
        store.send(.setDisplayStyle(style))
        if let readout { store.send(.readoutUpdated(readout)) }
        store.send(.setShowingSettings(showingSettings))
        return store
    }
}
#endif
