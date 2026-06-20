//
//  CopyLocalizationTests.swift
//  GibbousTests
//
//  All user-facing copy now flows through one mechanism: explicit
//  `LocalizedStringResource` constants declared in Swift (the source of truth),
//  with the catalog holding translations. These pin the English defaults for the
//  settings controls and the readout labels — the strings both skins share, so
//  the Modern and Retro faces can never drift apart.
//

import Foundation
import Testing

@testable import Gibbous

@MainActor
struct CopyLocalizationTests {
    @Test func settingsCopyResolvesToEnglishDefaults() {
        #expect(String(localized: SettingsCopy.theme) == "Theme")
        #expect(String(localized: SettingsCopy.phaseSounds) == "Phase Sounds")
        #expect(String(localized: SettingsCopy.startAtLogin) == "Start at Login")
        #expect(String(localized: SettingsCopy.quitGibbous) == "Quit Gibbous")
        #expect(String(localized: SettingsCopy.quit) == "Quit")
        #expect(String(localized: SettingsCopy.title) == "Settings")
    }

    @Test func readoutCopyResolvesToEnglishDefaults() {
        #expect(String(localized: ReadoutCopy.phasesTitle) == "Phases of the Moon")
        #expect(String(localized: ReadoutCopy.moonAgeTitle) == "Moon Age")
        #expect(String(localized: ReadoutCopy.subtendTitle) == "Subtend")
        #expect(String(localized: ReadoutCopy.distanceTitle) == "Distance")
        #expect(String(localized: ReadoutCopy.timeAndDateTitle) == "Time and Date")
        #expect(String(localized: ReadoutCopy.moon) == "Moon")
        #expect(String(localized: ReadoutCopy.sun) == "Sun")
        #expect(String(localized: ReadoutCopy.age) == "Age")
        #expect(String(localized: ReadoutCopy.lunation) == "Lunation")
        #expect(String(localized: ReadoutCopy.moonSubtend) == "Moon ∅")
        #expect(String(localized: ReadoutCopy.sunSubtend) == "Sun ∅")
        #expect(String(localized: ReadoutCopy.unavailable) == "Moon unavailable")
    }
}
