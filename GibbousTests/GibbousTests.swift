//
//  GibbousTests.swift
//  GibbousTests
//
//  End-to-end wiring of the configured store: it hydrates from the injected
//  key-value store at construction, and dispatched actions flow through the
//  reducer to mutate observable state.
//

import Foundation
import Testing

@testable import Gibbous

@MainActor
struct GibbousTests {
    @Test func configuredStoreHydratesFromTheInjectedPreferences() {
        let prefs = InMemoryKeyValueStore()
        prefs.setValue(.retro, for: .displayStyle)
        prefs.setValue(true, for: .soundsEnabled)

        let store = AppStore.stub(keyValue: prefs)
        #expect(store.displayStyle == .retro)
        #expect(store.soundsEnabled)
    }

    @Test func configuredStoreDefaultsWhenNoPreferencesArePersisted() {
        let store = AppStore.stub()
        #expect(store.displayStyle == .modern)
        #expect(store.soundsEnabled == false)
    }

    @Test func dispatchedActionsMutateObservableState() {
        let store = AppStore.stub()
        store.send(.setDisplayStyle(.retro))
        #expect(store.displayStyle == .retro)
        store.send(.setShowingSettings(true))
        #expect(store.isShowingSettings)
    }
}
