//
//  AppReducerTests.swift
//  GibbousTests
//
//  The pure reducer arms: state mutations, and that preference changes write
//  through to the KeyValueStore via their effect.
//

import Foundation
import Testing

@testable import Gibbous

@MainActor
struct AppReducerTests {
    struct StubUnavailable: Error {}
    let kv = InMemoryKeyValueStore()

    func makeReducer(playHowl: @escaping @Sendable () -> Void = {}) -> AppReducer {
        AppReducer(
            environment: AppEnvironment(
                keyValue: kv,
                timeZone: TimeZone.gmt,
                now: { Date(timeIntervalSinceReferenceDate: 0) },
                computeReadout: { _, _, _ in throw StubUnavailable() },
                playHowl: playHowl
            ))
    }

    /// Run a reducer-returned effect to completion (for write-through checks).
    func run(_ effect: AppEffect?) async {
        let noop: @MainActor @Sendable (AppAction) -> Void = { _ in }
        await effect?(noop)
    }

    @Test func setDisplayStyleMutatesAndPersists() async {
        let reducer = makeReducer()
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .setDisplayStyle(.retro)))
        #expect(state.displayStyle == .retro)
        #expect(kv.value(.displayStyle) == .retro)
    }

    @Test func setSoundsEnabledMutatesAndPersists() async {
        let reducer = makeReducer()
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .setSoundsEnabled(true)))
        #expect(state.soundsEnabled)
        #expect(kv.value(.soundsEnabled) == true)
    }

    @Test func tickReturnsAReadoutRecomputeEffect() {
        let reducer = makeReducer()
        var state = AppState()
        let effect = reducer.reduce(state: &state, action: .tick(Date(timeIntervalSinceReferenceDate: 12_345)))
        #expect(effect != nil)  // the tick exists only to drive the recompute
    }

    // MARK: Lunation-event caching

    final class ReuseSpy: @unchecked Sendable { var calls: [LunationEvents?] = [] }

    /// A reducer whose compute records the `reuse` it's handed and returns `seed`.
    func makeReusingReducer(spy: ReuseSpy, seed: MoonReadout) -> AppReducer {
        AppReducer(
            environment: AppEnvironment(
                keyValue: kv,
                timeZone: TimeZone.gmt,
                now: { Date(timeIntervalSinceReferenceDate: 0) },
                computeReadout: { _, _, reuse in
                    spy.calls.append(reuse)
                    return seed
                },
                playHowl: {}
            ))
    }

    func lunationReadout(now: Date, lastNew: Date, nextNew: Date) -> MoonReadout {
        MoonReadout(
            now: now, timeZone: TimeZone.gmt,
            phaseAngleDegrees: 90, illuminatedFraction: 0.5, isWaxing: true, phaseName: "First Quarter",
            julianDate: 0, moonDistanceKM: 0, moonDistanceEarthRadii: 0,
            sunDistanceAU: 0, sunDistanceKM: 0, moonSubtendDegrees: 0, sunSubtendDegrees: 0,
            lunationNumber: 1, moonAge: MoonAge(days: 0, hours: 0, minutes: 0),
            lastNewMoon: lastNew, firstQuarter: lastNew, fullMoon: now,
            lastQuarter: nextNew, nextNewMoon: nextNew,
            subEarthLatitude: 0, subEarthLongitude: 0)
    }

    @Test func tickReusesLunationEventsWithinTheWindowAndRecomputesAcross() async {
        let spy = ReuseSpy()
        let lastNew = Date(timeIntervalSinceReferenceDate: 0)
        let nextNew = lastNew.addingTimeInterval(29.5 * 86_400)
        let seed = lunationReadout(now: lastNew, lastNew: lastNew, nextNew: nextNew)
        let reducer = makeReusingReducer(spy: spy, seed: seed)
        var state = AppState()
        state.readout = seed

        // A tick still inside the lunation reuses the cached events.
        await run(reducer.reduce(state: &state, action: .tick(lastNew.addingTimeInterval(86_400))))
        #expect(spy.calls.last! != nil)

        // A tick past the next new moon forces a recompute (no events to reuse).
        await run(reducer.reduce(state: &state, action: .tick(nextNew.addingTimeInterval(60))))
        #expect(spy.calls.last! == nil)
    }

    @Test func tickWithoutAReadoutHasNothingToReuse() async {
        let spy = ReuseSpy()
        let seed = lunationReadout(
            now: .distantPast, lastNew: .distantPast, nextNew: .distantFuture)
        let reducer = makeReusingReducer(spy: spy, seed: seed)
        var state = AppState()  // no readout yet
        await run(reducer.reduce(state: &state, action: .tick(Date(timeIntervalSinceReferenceDate: 0))))
        #expect(spy.calls.last! == nil)
    }

    @Test func readoutUpdatedStoresAndClearsUnavailable() {
        let reducer = makeReducer()
        var state = AppState()
        state.isUnavailable = true
        let r = try! MoonAlmanac.readout(at: Date(timeIntervalSince1970: 1_700_000_000), timeZone: .current)
        _ = reducer.reduce(state: &state, action: .readoutUpdated(r))
        #expect(state.readout == r)
        #expect(state.isUnavailable == false)
    }

    @Test func readoutUnavailableSetsFlag() {
        let reducer = makeReducer()
        var state = AppState()
        _ = reducer.reduce(state: &state, action: .readoutUnavailable)
        #expect(state.isUnavailable)
    }

    // MARK: Charm — full-moon howl

    final class HowlSpy: @unchecked Sendable { var count = 0 }

    func fullMoonReadout(now: Date, full: Date) -> MoonReadout {
        MoonReadout(
            now: now, timeZone: TimeZone.gmt,
            phaseAngleDegrees: 180, illuminatedFraction: 1, isWaxing: false, phaseName: "Full Moon",
            julianDate: 0, moonDistanceKM: 0, moonDistanceEarthRadii: 0,
            sunDistanceAU: 0, sunDistanceKM: 0, moonSubtendDegrees: 0, sunSubtendDegrees: 0,
            lunationNumber: 0, moonAge: MoonAge(days: 0, hours: 0, minutes: 0),
            lastNewMoon: .distantPast, firstQuarter: .distantPast, fullMoon: full,
            lastQuarter: .distantFuture, nextNewMoon: .distantFuture,
            subEarthLatitude: 0, subEarthLongitude: 0)
    }

    @Test func howlsOnceOnLiveFullMoonCrossingWhenEnabled() async {
        let spy = HowlSpy()
        let reducer = makeReducer(playHowl: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = true
        let full = Date(timeIntervalSinceReferenceDate: 1_000)

        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(-5), full: full))))
        #expect(spy.count == 0)  // armed, before full
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(1), full: full))))
        #expect(spy.count == 1)  // crossed → howl
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(2), full: full))))
        #expect(spy.count == 1)  // debounced, no re-fire
    }

    @Test func doesNotHowlWhenSoundsDisabled() async {
        let spy = HowlSpy()
        let reducer = makeReducer(playHowl: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = false
        let full = Date(timeIntervalSinceReferenceDate: 1_000)
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(-5), full: full))))
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(1), full: full))))
        #expect(spy.count == 0)
    }

    @Test func doesNotHowlForAFullMoonAlreadyPastAtLaunch() async {
        let spy = HowlSpy()
        let reducer = makeReducer(playHowl: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = true
        let full = Date(timeIntervalSinceReferenceDate: 1_000)
        // First readout already past full → never armed → no howl.
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(60), full: full))))
        #expect(spy.count == 0)
    }
}
