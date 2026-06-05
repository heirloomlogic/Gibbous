//
//  AppAction.swift
//  Gibbous
//
//  Events and intents. Async work (the clock, ephemeris computation, writing
//  preferences) lives in effects returned by the reducer, never here.
//

import CoreGraphics
import Foundation

nonisolated enum AppAction: Sendable {
    /// Start the 1-second clock loop (dispatched once at launch).
    case startClock
    /// The clock advanced "now" to this instant.
    case tick(Date)
    /// A fresh readout was computed off-main.
    case readoutUpdated(MoonReadout)
    /// Ephemeris was unavailable for this instant.
    case readoutUnavailable

    case setDisplayStyle(DisplayStyle)
    case setDensity(Density)
    case setPresentation(Presentation)
    case setFloatingFrame(CGRect)
    case setAlwaysOnTop(Bool)
    case setSoundsEnabled(Bool)
}

typealias AppEffect = Swidux.Effect<AppAction>
typealias AppSend = Swidux.Send<AppAction>
