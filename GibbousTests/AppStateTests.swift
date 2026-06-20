//
//  AppStateTests.swift
//  GibbousTests
//
//  State defaults and launch hydration: the persisted preferences are pulled
//  from the key-value store once at start, and everything else begins in its
//  ephemeral default. Also pins the persistence key names, which the store
//  payload depends on.
//

import Foundation
import Testing

@testable import Gibbous

struct AppStateTests {
    @Test func defaultsAreModernSilentAndEphemeral() {
        let state = AppState()
        #expect(state.displayStyle == .modern)
        #expect(state.soundsEnabled == false)
        #expect(state.readout == nil)
        #expect(state.isUnavailable == false)
        #expect(state.isShowingSettings == false)
        #expect(state.isPopoverShown == false)
        #expect(state.armedFullMoon == nil)
        #expect(state.lastFiredFullMoon == nil)
        #expect(state.seenNewMoon == nil)
        #expect(state.launchAtLogin == false)
    }

    @Test func hydrationFromAnEmptyStoreKeepsDefaults() {
        let state = AppState.hydrated(from: InMemoryKeyValueStore())
        #expect(state.displayStyle == .modern)
        #expect(state.soundsEnabled == false)
        #expect(state.launchAtLogin == false)
    }

    @Test func hydrationPullsPersistedPreferences() {
        let store = InMemoryKeyValueStore()
        store.setValue(.retro, for: .displayStyle)
        store.setValue(true, for: .soundsEnabled)
        store.setValue(true, for: .launchAtLogin)

        let state = AppState.hydrated(from: store)
        #expect(state.displayStyle == .retro)
        #expect(state.soundsEnabled)
        #expect(state.launchAtLogin)
    }

    @Test func persistenceKeyNamesAreStable() {
        // These names are the on-disk contract — changing them silently drops
        // a user's saved preference, so they're pinned.
        #expect(KVKey<DisplayStyle>.displayStyle.name == "displayStyle")
        #expect(KVKey<Bool>.soundsEnabled.name == "soundsEnabled")
        #expect(KVKey<Bool>.launchAtLogin.name == "launchAtLogin")
    }
}
