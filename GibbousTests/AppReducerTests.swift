//
//  AppReducerTests.swift
//  GibbousTests
//
//  The pure reducer arms: state mutations, and that preference changes write
//  through to the KeyValueStore via their effect.
//

import CoreGraphics
import Foundation
import Testing
@testable import Gibbous

@MainActor
struct AppReducerTests {

    struct StubUnavailable: Error {}
    let kv = InMemoryKeyValueStore()

    func makeReducer(playHowl: @escaping @Sendable () -> Void = {}) -> AppReducer {
        AppReducer(environment: AppEnvironment(
            keyValue: kv,
            timeZone: TimeZone(identifier: "UTC")!,
            now: { Date(timeIntervalSinceReferenceDate: 0) },
            computeReadout: { _, _ in throw StubUnavailable() },
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

    @Test func setDensityMutatesAndPersists() async {
        let reducer = makeReducer()
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .setDensity(.moonOnly)))
        #expect(state.density == .moonOnly)
        #expect(kv.value(.density) == .moonOnly)
    }

    @Test func setSoundsEnabledMutatesAndPersists() async {
        let reducer = makeReducer()
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .setSoundsEnabled(true)))
        #expect(state.soundsEnabled)
        #expect(kv.value(.soundsEnabled) == true)
    }

    @Test func setPresentationAndFrameMutate() {
        let reducer = makeReducer()
        var state = AppState()
        _ = reducer.reduce(state: &state, action: .setPresentation(.floating))
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)
        _ = reducer.reduce(state: &state, action: .setFloatingFrame(frame))
        #expect(state.presentation == .floating)
        #expect(state.floatingFrame == frame)
    }

    @Test func tickReturnsAReadoutRecomputeEffect() {
        let reducer = makeReducer()
        var state = AppState()
        let effect = reducer.reduce(state: &state, action: .tick(Date(timeIntervalSinceReferenceDate: 12_345)))
        #expect(effect != nil)   // the tick exists only to drive the recompute
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
            now: now, timeZone: TimeZone(identifier: "UTC")!,
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
        var state = AppState(); state.soundsEnabled = true
        let full = Date(timeIntervalSinceReferenceDate: 1_000)

        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(-5), full: full))))
        #expect(spy.count == 0)                       // armed, before full
        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(1), full: full))))
        #expect(spy.count == 1)                       // crossed → howl
        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(2), full: full))))
        #expect(spy.count == 1)                       // debounced, no re-fire
    }

    @Test func doesNotHowlWhenSoundsDisabled() async {
        let spy = HowlSpy()
        let reducer = makeReducer(playHowl: { spy.count += 1 })
        var state = AppState(); state.soundsEnabled = false
        let full = Date(timeIntervalSinceReferenceDate: 1_000)
        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(-5), full: full))))
        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(1), full: full))))
        #expect(spy.count == 0)
    }

    @Test func doesNotHowlForAFullMoonAlreadyPastAtLaunch() async {
        let spy = HowlSpy()
        let reducer = makeReducer(playHowl: { spy.count += 1 })
        var state = AppState(); state.soundsEnabled = true
        let full = Date(timeIntervalSinceReferenceDate: 1_000)
        // First readout already past full → never armed → no howl.
        await run(reducer.reduce(state: &state, action: .readoutUpdated(fullMoonReadout(now: full.addingTimeInterval(60), full: full))))
        #expect(spy.count == 0)
    }
}
