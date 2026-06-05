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
            // separately — the tick exists only to drive the recompute.
            return computeReadout(for: date)

        case .readoutUpdated(let readout):
            state.readout = readout
            state.isUnavailable = false
            return fullMoonHowl(state: &state, readout: readout)

        case .readoutUnavailable:
            state.isUnavailable = true
            return nil

        case .setDisplayStyle(let value):
            state.displayStyle = value
            return persist(value, for: .displayStyle)

        case .setDensity(let value):
            state.density = value
            return persist(value, for: .density)

        case .setPresentation(let value):
            state.presentation = value
            return persist(value, for: .presentation)

        case .setFloatingFrame(let frame):
            state.floatingFrame = frame
            return persist(frame, for: .floatingFrame)

        case .setAlwaysOnTop(let value):
            state.alwaysOnTop = value
            return persist(value, for: .alwaysOnTop)

        case .setSoundsEnabled(let value):
            state.soundsEnabled = value
            return persist(value, for: .soundsEnabled)
        }
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
    private func computeReadout(for date: Date) -> AppEffect {
        let compute = environment.computeReadout
        let timeZone = environment.timeZone
        return { send in
            if let readout = try? compute(date, timeZone) {
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

    /// Write a scalar preference to the key-value store.
    private func persist<Value: Sendable>(_ value: Value, for key: KVKey<Value>) -> AppEffect {
        let store = environment.keyValue
        return { _ in store.setValue(value, for: key) }
    }
}
