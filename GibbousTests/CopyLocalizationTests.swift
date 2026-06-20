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

    // The catalog now ships translations for ten languages. These force a couple
    // of non-English locales and assert the catalog actually resolves to the
    // translated values — a guard against a key drifting out of the catalog or a
    // translation going missing/empty. (The English tests above only exercise the
    // Swift `defaultValue`, which would still pass even with no catalog at all.)
    private func localized(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: identifier)
        return String(localized: resource)
    }

    @Test func copyResolvesInGerman() {
        #expect(localized(SettingsCopy.theme, "de") == "Design")
        #expect(localized(SettingsCopy.title, "de") == "Einstellungen")
        #expect(localized(SettingsCopy.quitGibbous, "de") == "Gibbous beenden")
        #expect(localized(ReadoutCopy.distanceTitle, "de") == "Entfernung")
        #expect(localized(ReadoutCopy.moonSubtend, "de") == "Mond ∅")
    }

    @Test func copyResolvesInJapanese() {
        #expect(localized(ReadoutCopy.moon, "ja") == "月")
        #expect(localized(ReadoutCopy.sun, "ja") == "太陽")
        #expect(localized(ReadoutCopy.phasesTitle, "ja") == "月の満ち欠け")
    }
}
