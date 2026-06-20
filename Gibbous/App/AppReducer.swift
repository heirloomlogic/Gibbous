//
//  AppReducer.swift
//  Gibbous
//
//  Pure, synchronous reducer. Mutations happen in place; anything async — the
//  clock loop, ephemeris computation, persisting a preference — is returned as
//  an effect that captures only `environment` (never mutable state).
//

import Foundation

nonisolated struct AppReducer {
    let environment: AppEnvironment

    func reduce(state: inout AppState, action: AppAction) -> AppEffect? {
        switch action {
        case .startClock:
            return clockLoop()

        case .tick(let date):
            // The live clock is read from the recomputed readout, not stored
            // separately — the tick exists only to drive the recompute. While
            // the popover is hidden nothing on screen reads the per-second clock,
            // so we throttle the expensive ephemeris recompute (see
            // `shouldRecompute`); the 1 s tick keeps running so crossings are
            // still caught promptly.
            guard shouldRecompute(state: state, at: date) else { return nil }
            return recomputeReadout(state: state, for: date)

        case .readoutUpdated(let readout):
            state.readout = readout
            state.isUnavailable = false
            // Run both phase cues for their arming side effects; at most one can
            // fire on a single readout (full and new moons are ~14.75 days apart).
            let howl = fullMoonHowl(state: &state, readout: readout)
            let hoot = newMoonHoot(state: &state, readout: readout)
            return howl ?? hoot

        case .readoutUnavailable:
            state.isUnavailable = true
            return nil

        case .setDisplayStyle(let value):
            state.displayStyle = value
            return persist(value, for: .displayStyle)

        case .setSoundsEnabled(let value):
            state.soundsEnabled = value
            return persist(value, for: .soundsEnabled)

        case .setLaunchAtLogin(let value):
            state.launchAtLogin = value  // optimistic, for a snappy toggle
            return resolveLoginItem(applying: value)

        case .syncLaunchAtLogin:
            return resolveLoginItem()

        case .launchAtLoginResolved(let enabled):
            state.launchAtLogin = enabled
            return persist(enabled, for: .launchAtLogin)

        case .setShowingSettings(let value):
            state.isShowingSettings = value
            return nil

        case .setPopoverShown(let value):
            state.isPopoverShown = value
            guard value else {
                // Popover closed: drop back to the front face while hidden, so the
                // next open never shows the settings face mid-dissolve.
                state.isShowingSettings = false
                return nil
            }
            // Showing the popover after a throttled spell can leave the clock
            // up to one coarse interval stale — refresh immediately on open.
            return recomputeReadout(state: state, for: environment.now())
        }
    }

    // MARK: - Recompute cadence

    /// Coarse background recompute cadence while the popover is hidden. While
    /// shown we recompute every tick (a live seconds clock); while hidden we
    /// only need to keep the glyph fresh and catch the full-moon crossing — a
    /// new-moon crossing leaves the lunation and recomputes promptly regardless.
    private static let backgroundRecomputeInterval: TimeInterval = 30

    /// Whether `date` warrants a fresh (expensive) ephemeris recompute.
    private func shouldRecompute(state: AppState, at date: Date) -> Bool {
        guard let readout = state.readout else { return true }  // no readout yet
        if state.isPopoverShown { return true }  // live seconds clock on screen
        if !readout.containsLunation(of: date) { return true }  // crossed a lunation boundary
        if date < readout.now { return true }  // clock moved backward
        return date.timeIntervalSince(readout.now) >= Self.backgroundRecomputeInterval
    }

    /// Build the recompute effect for `date`, reusing the current lunation's
    /// phase events while "now" is still inside it so only the cheap
    /// instantaneous queries run.
    private func recomputeReadout(state: AppState, for date: Date) -> AppEffect {
        let reuse = state.readout.flatMap {
            $0.containsLunation(of: date) ? $0.lunationEvents : nil
        }
        return computeReadout(for: date, reusing: reuse)
    }

    // MARK: - Effects

    /// Tick once a second so the clock and readout stay live for the app's life.
    private func clockLoop() -> AppEffect {
        let now = environment.now
        return { send in
            while !Task.isCancelled {
                await send(.tick(now()))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Compute the readout off the main actor; throwing yields "unavailable".
    /// `reuse` carries the current lunation's events when they still apply.
    private func computeReadout(for date: Date, reusing reuse: LunationEvents?) -> AppEffect {
        let compute = environment.computeReadout
        let timeZone = environment.timeZone
        return { send in
            if let readout = try? compute(date, timeZone, reuse) {
                await send(.readoutUpdated(readout))
            } else {
                await send(.readoutUnavailable)
            }
        }
    }

    /// The flagship charm cue: howl once as "now" crosses the full moon. We
    /// arm only while the full moon is still ahead, so a full moon already past
    /// at launch never fires; the crossing is consumed regardless of whether
    /// sounds are on, so toggling sounds on long after never howls late.
    private func fullMoonHowl(state: inout AppState, readout: MoonReadout) -> AppEffect? {
        let full = readout.fullMoon
        if readout.now < full {
            state.armedFullMoon = full
            return nil
        }
        guard state.armedFullMoon == full, state.lastFiredFullMoon != full else { return nil }
        state.lastFiredFullMoon = full
        guard state.soundsEnabled else { return nil }
        let play = environment.playHowl
        return { _ in play() }
    }

    /// The new-moon counterpart to the howl. The new moon bounds the lunation,
    /// so unlike the full moon its date rolls forward at the crossing — we
    /// detect the crossing by watching the most-recent new moon advance, seeding
    /// on the first readout so a new moon already past at launch never fires.
    private func newMoonHoot(state: inout AppState, readout: MoonReadout) -> AppEffect? {
        let last = readout.lastNewMoon
        guard let seen = state.seenNewMoon else {
            state.seenNewMoon = last  // first readout: adopt the current new moon as already-seen
            return nil
        }
        guard last != seen else { return nil }  // same lunation, nothing crossed
        state.seenNewMoon = last  // the new moon advanced → we crossed it live
        guard state.soundsEnabled else { return nil }
        let play = environment.playHoot
        return { _ in play() }
    }

    /// Write a scalar preference to the key-value store.
    private func persist<Value: Sendable>(_ value: Value, for key: KVKey<Value>) -> AppEffect {
        let store = environment.keyValue
        return { _ in store.setValue(value, for: key) }
    }

    /// Reconcile the login item with the system: optionally apply a new on/off
    /// value (the user toggled), then re-read the actual state and resolve to it.
    /// A failed register/unregister — or a change made in System Settings while
    /// the app was closed — self-corrects, since we always resolve to reality.
    private func resolveLoginItem(applying enabled: Bool? = nil) -> AppEffect {
        let setEnabled = environment.setLoginItemEnabled
        let isEnabled = environment.loginItemEnabled
        return { send in
            if let enabled { setEnabled(enabled) }
            await send(.launchAtLoginResolved(isEnabled()))
        }
    }
}
