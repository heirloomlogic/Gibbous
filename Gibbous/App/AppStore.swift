//
//  AppStore.swift
//  Gibbous
//
//  Wires the store. Gibbous needs no plugins — no persistence middleware (the
//  only persisted values are scalar preferences, written from effects), no
//  undo, no analytics/paywall/killswitch. Just the reducer over hydrated state.
//

import Foundation

typealias AppStore = Store<AppState, AppAction>

extension Store where State == AppState, Action == AppAction {
    static func configured(environment: AppEnvironment = .live()) -> AppStore {
        let reducer = AppReducer(environment: environment)
        return Store(
            initialState: .hydrated(from: environment.keyValue),
            reducer: { state, action in reducer.reduce(state: &state, action: action) }
        )
    }
}
