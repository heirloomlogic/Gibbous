//
//  SampleReadout.swift
//  GibbousTests
//
//  Shared test fixtures: the ephemeris-free sample readout (delegating to the
//  app's canonical `MoonReadout.sample` so previews and tests can't drift) and a
//  stubbed store for unit tests that drive the reducer action-by-action.
//

import Foundation

@testable import Gibbous

enum SampleReadout {
    /// 2014-10-05 21:58:18 UTC — the golden-master instant, reused so the
    /// numbers line up with `MoonAlmanacGoldenTests` where they overlap.
    static let instant = Date(timeIntervalSince1970: 1_412_546_298)

    /// A waxing-gibbous readout with hand-set, locale-independent values. Thin
    /// wrapper over `MoonReadout.sample` — defined once in the app target.
    static func make(now: Date = instant, timeZone: TimeZone = .gmt) -> MoonReadout {
        MoonReadout.sample(now: now, timeZone: timeZone)
    }
}

extension AppStore {
    /// A store with stubbed effects and a fixed clock, for unit tests that drive
    /// it action-by-action. Shared so adding a field to `AppEnvironment` only
    /// touches one call site.
    @MainActor static func stub(
        keyValue: InMemoryKeyValueStore = InMemoryKeyValueStore(),
        setLoginItemEnabled: @escaping @Sendable (Bool) -> Void = { _ in },
        loginItemEnabled: @escaping @Sendable () -> Bool = { false }
    ) -> AppStore {
        AppStore.configured(
            environment: AppEnvironment(
                keyValue: keyValue,
                timeZone: .gmt,
                now: { Date(timeIntervalSinceReferenceDate: 0) },
                computeReadout: { _, _, _ in MoonReadout.sample() },
                playHowl: {},
                playHoot: {},
                setLoginItemEnabled: setLoginItemEnabled,
                loginItemEnabled: loginItemEnabled
            ))
    }
}
