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

    func makeReducer(
        playHowl: @escaping @Sendable () -> Void = {},
        playHoot: @escaping @Sendable () -> Void = {},
        setLoginItemEnabled: @escaping @Sendable (Bool) -> Void = { _ in },
        loginItemEnabled: @escaping @Sendable () -> Bool = { false }
    ) -> AppReducer {
        AppReducer(
            environment: AppEnvironment(
                keyValue: kv,
                timeZone: TimeZone.gmt,
                now: { Date(timeIntervalSinceReferenceDate: 0) },
                computeReadout: { _, _, _ in throw StubUnavailable() },
                playHowl: playHowl,
                playHoot: playHoot,
                setLoginItemEnabled: setLoginItemEnabled,
                loginItemEnabled: loginItemEnabled
            ))
    }

    /// Run a reducer-returned effect to completion (for write-through checks).
    func run(_ effect: AppEffect?) async {
        let noop: @MainActor @Sendable (AppAction) -> Void = { _ in }
        await effect?(noop)
    }

    /// Run an effect, capturing the actions it dispatches back (for the
    /// login-item sync flow, which resolves via a follow-up action).
    func capture(_ effect: AppEffect?) async -> [AppAction] {
        let box = ActionBox()
        let send: @MainActor @Sendable (AppAction) -> Void = { box.actions.append($0) }
        await effect?(send)
        return box.actions
    }
    final class ActionBox: @unchecked Sendable { var actions: [AppAction] = [] }

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

    // MARK: Start at Login

    /// Captures the last on/off value handed to the injected login-item closure.
    final class LoginItemSpy: @unchecked Sendable { var lastSet: Bool? }

    /// The values carried by any `.launchAtLoginResolved` actions in a capture.
    func resolvedLaunchValues(_ actions: [AppAction]) -> [Bool] {
        actions.compactMap {
            if case .launchAtLoginResolved(let v) = $0 { return v }
            return nil
        }
    }

    @Test func setLaunchAtLoginMutatesOptimisticallyAndRegisters() async {
        let spy = LoginItemSpy()
        let reducer = makeReducer(setLoginItemEnabled: { spy.lastSet = $0 })
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .setLaunchAtLogin(true)))
        #expect(state.launchAtLogin)  // optimistic
        #expect(spy.lastSet == true)  // register() called via the injected closure
    }

    @Test func setLaunchAtLoginOffUnregisters() async {
        let spy = LoginItemSpy()
        let reducer = makeReducer(setLoginItemEnabled: { spy.lastSet = $0 })
        var state = AppState()
        state.launchAtLogin = true
        await run(reducer.reduce(state: &state, action: .setLaunchAtLogin(false)))
        #expect(state.launchAtLogin == false)
        #expect(spy.lastSet == false)
    }

    @Test func setLaunchAtLoginResolvesToTheActualSystemState() async {
        // The toggle is optimistic, but the effect re-reads the real status and
        // dispatches `.launchAtLoginResolved` with it — so a failed register
        // self-corrects. Here the system reports "off" despite the on request.
        let reducer = makeReducer(setLoginItemEnabled: { _ in }, loginItemEnabled: { false })
        var state = AppState()
        let dispatched = await capture(reducer.reduce(state: &state, action: .setLaunchAtLogin(true)))
        #expect(resolvedLaunchValues(dispatched) == [false])
    }

    @Test func launchAtLoginResolvedMutatesAndPersists() async {
        let reducer = makeReducer()
        var state = AppState()
        await run(reducer.reduce(state: &state, action: .launchAtLoginResolved(true)))
        #expect(state.launchAtLogin)
        #expect(kv.value(.launchAtLogin) == true)
    }

    @Test func syncLaunchAtLoginResolvesToTheInjectedSystemState() async {
        // Launch reconcile: read the system status and resolve to it (the user
        // may have toggled the login item in System Settings).
        let reducer = makeReducer(loginItemEnabled: { true })
        var state = AppState()
        let dispatched = await capture(reducer.reduce(state: &state, action: .syncLaunchAtLogin))
        #expect(resolvedLaunchValues(dispatched) == [true])
    }

    @Test func tickReturnsAReadoutRecomputeEffect() {
        let reducer = makeReducer()
        var state = AppState()
        let effect = reducer.reduce(state: &state, action: .tick(Date(timeIntervalSinceReferenceDate: 12_345)))
        #expect(effect != nil)  // the tick exists only to drive the recompute
    }

    @Test func startClockReturnsTheClockLoopEffect() {
        let reducer = makeReducer()
        var state = AppState()
        // The loop runs for the app's life, so we only assert it's wired up —
        // running it to completion would never return.
        #expect(reducer.reduce(state: &state, action: .startClock) != nil)
    }

    // MARK: Settings face

    @Test func setShowingSettingsTogglesTheFlagWithoutAnEffect() {
        let reducer = makeReducer()
        var state = AppState()
        #expect(reducer.reduce(state: &state, action: .setShowingSettings(true)) == nil)
        #expect(state.isShowingSettings)
        #expect(reducer.reduce(state: &state, action: .setShowingSettings(false)) == nil)
        #expect(state.isShowingSettings == false)
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
                playHowl: {},
                playHoot: {},
                setLoginItemEnabled: { _ in },
                loginItemEnabled: { false }
            ))
    }

    func lunationReadout(now: Date, lastNew: Date, nextNew: Date) -> MoonReadout {
        MoonReadout(
            now: now, timeZone: TimeZone.gmt,
            phaseAngleDegrees: 90, illuminatedFraction: 0.5, isWaxing: true,
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

    // MARK: Recompute cadence (throttle while the popover is hidden)

    /// A readout whose lunation window brackets `now`, for cadence tests.
    func cadenceReadout(now: Date) -> MoonReadout {
        let lastNew = now
        let nextNew = now.addingTimeInterval(29.5 * 86_400)
        return lunationReadout(now: now, lastNew: lastNew, nextNew: nextNew)
    }

    @Test func tickRecomputesEverySecondWhilePopoverShown() {
        let reducer = makeReducer()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var state = AppState()
        state.readout = cadenceReadout(now: t0)
        state.isPopoverShown = true
        // One second later, still "fresh" — but shown means recompute for the
        // live seconds clock.
        let effect = reducer.reduce(state: &state, action: .tick(t0.addingTimeInterval(1)))
        #expect(effect != nil)
    }

    @Test func tickThrottlesRecomputeWhileHiddenAndFresh() {
        let reducer = makeReducer()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var state = AppState()
        state.readout = cadenceReadout(now: t0)
        state.isPopoverShown = false
        // Within the coarse interval and hidden → no recompute.
        let effect = reducer.reduce(state: &state, action: .tick(t0.addingTimeInterval(5)))
        #expect(effect == nil)
    }

    @Test func tickRecomputesWhileHiddenOnceStale() {
        let reducer = makeReducer()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        var state = AppState()
        state.readout = cadenceReadout(now: t0)
        state.isPopoverShown = false
        // Past the coarse interval → recompute to keep the glyph fresh.
        let effect = reducer.reduce(state: &state, action: .tick(t0.addingTimeInterval(31)))
        #expect(effect != nil)
    }

    @Test func showingPopoverRefreshesImmediatelyAndSetsFlag() {
        let reducer = makeReducer()
        var state = AppState()
        let effect = reducer.reduce(state: &state, action: .setPopoverShown(true))
        #expect(state.isPopoverShown)
        #expect(effect != nil)  // immediate refresh so the clock isn't stale on open
    }

    @Test func hidingPopoverSetsFlagWithoutRefresh() {
        let reducer = makeReducer()
        var state = AppState()
        state.isPopoverShown = true
        let effect = reducer.reduce(state: &state, action: .setPopoverShown(false))
        #expect(state.isPopoverShown == false)
        #expect(effect == nil)
    }

    @Test func hidingPopoverResetsToTheFrontFace() {
        // Closing on the settings face drops back to the front while hidden, so
        // the next open never flashes the settings face mid-dissolve.
        let reducer = makeReducer()
        var state = AppState()
        state.isPopoverShown = true
        state.isShowingSettings = true
        _ = reducer.reduce(state: &state, action: .setPopoverShown(false))
        #expect(state.isShowingSettings == false)
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

    /// Counts how many times a charm cue (`playHowl`/`playHoot`) fired.
    final class CharmCueSpy: @unchecked Sendable { var count = 0 }

    func fullMoonReadout(now: Date, full: Date) -> MoonReadout {
        MoonReadout(
            now: now, timeZone: TimeZone.gmt,
            phaseAngleDegrees: 180, illuminatedFraction: 1, isWaxing: false,
            julianDate: 0, moonDistanceKM: 0, moonDistanceEarthRadii: 0,
            sunDistanceAU: 0, sunDistanceKM: 0, moonSubtendDegrees: 0, sunSubtendDegrees: 0,
            lunationNumber: 0, moonAge: MoonAge(days: 0, hours: 0, minutes: 0),
            lastNewMoon: .distantPast, firstQuarter: .distantPast, fullMoon: full,
            lastQuarter: .distantFuture, nextNewMoon: .distantFuture,
            subEarthLatitude: 0, subEarthLongitude: 0)
    }

    @Test func howlsOnceOnLiveFullMoonCrossingWhenEnabled() async {
        let spy = CharmCueSpy()
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
        let spy = CharmCueSpy()
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
        let spy = CharmCueSpy()
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

    // MARK: Charm — new-moon hoot

    func newMoonReadout(now: Date, lastNew: Date) -> MoonReadout {
        MoonReadout(
            now: now, timeZone: TimeZone.gmt,
            phaseAngleDegrees: 0, illuminatedFraction: 0, isWaxing: true,
            julianDate: 0, moonDistanceKM: 0, moonDistanceEarthRadii: 0,
            sunDistanceAU: 0, sunDistanceKM: 0, moonSubtendDegrees: 0, sunSubtendDegrees: 0,
            lunationNumber: 0, moonAge: MoonAge(days: 0, hours: 0, minutes: 0),
            lastNewMoon: lastNew, firstQuarter: now, fullMoon: now,
            lastQuarter: now, nextNewMoon: lastNew.addingTimeInterval(29.5 * 86_400),
            subEarthLatitude: 0, subEarthLongitude: 0)
    }

    @Test func hootsOnceOnLiveNewMoonCrossingWhenEnabled() async {
        let spy = CharmCueSpy()
        let reducer = makeReducer(playHoot: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = true
        let n0 = Date(timeIntervalSinceReferenceDate: 0)
        let n1 = n0.addingTimeInterval(29.5 * 86_400)

        // First readout seeds the current new moon as already-seen.
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n0.addingTimeInterval(60), lastNew: n0))))
        #expect(spy.count == 0)  // seeded, nothing crossed
        // The lunation rolls over: lastNewMoon advances → crossed → hoot.
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n1.addingTimeInterval(1), lastNew: n1))))
        #expect(spy.count == 1)  // crossed → hoot
        // Still in the new lunation → no re-fire.
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n1.addingTimeInterval(2), lastNew: n1))))
        #expect(spy.count == 1)  // debounced, no re-fire
    }

    @Test func doesNotHootWhenSoundsDisabled() async {
        let spy = CharmCueSpy()
        let reducer = makeReducer(playHoot: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = false
        let n0 = Date(timeIntervalSinceReferenceDate: 0)
        let n1 = n0.addingTimeInterval(29.5 * 86_400)
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n0.addingTimeInterval(60), lastNew: n0))))
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n1.addingTimeInterval(1), lastNew: n1))))
        #expect(spy.count == 0)
    }

    @Test func doesNotHootForANewMoonAlreadyPastAtLaunch() async {
        let spy = CharmCueSpy()
        let reducer = makeReducer(playHoot: { spy.count += 1 })
        var state = AppState()
        state.soundsEnabled = true
        let n0 = Date(timeIntervalSinceReferenceDate: 0)
        // First-ever readout seeds seenNewMoon → the new moon past at launch never hoots.
        await run(
            reducer.reduce(
                state: &state, action: .readoutUpdated(newMoonReadout(now: n0.addingTimeInterval(60), lastNew: n0))))
        #expect(spy.count == 0)
    }
}
