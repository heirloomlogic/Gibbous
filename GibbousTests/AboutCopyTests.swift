//
//  AboutCopyTests.swift
//  GibbousTests
//
//  The credit copy is the single source of truth both skins render, and it
//  carries legal guardrails (naming the originals, AstronomyKit, and the
//  product name kept verbatim). These pin the proper nouns and the maker link.
//

import Foundation
import Testing

@testable import Gibbous

@MainActor
struct AboutCopyTests {
    @Test func productNameIsTheVerbatimProperNoun() {
        #expect(AboutCopy.name == "Gibbous")
    }

    @Test func heirloomLinkPointsAtTheMaker() throws {
        let url = try #require(AboutCopy.heirloomURL)
        #expect(url.absoluteString == "https://heirloomlogic.com/")
        #expect(url.scheme == "https")
    }

    @Test func taglineResolvesToItsEnglishDefault() {
        #expect(String(localized: AboutCopy.tagline) == "A menu-bar moon companion for the Mac.")
    }

    @Test func dedicationKeepsTheDedicateeInitials() {
        #expect(String(localized: AboutCopy.dedication).contains("KJS"))
    }

    @Test func homageNamesTheOriginalsAndTheLibrary() {
        let homage = String(localized: AboutCopy.homage)
        #expect(homage.contains("Moontool"))
        #expect(homage.contains("John Walker"))
        #expect(homage.contains("Richard Knuckey"))
        #expect(homage.contains("AstronomyKit"))
    }

    @Test func observatoryCopyNamesTheSiblingApps() {
        #expect(String(localized: AboutCopy.observatoryHeader) == "FROM THE SAME OBSERVATORY")
        #expect(String(localized: AboutCopy.observatoryFallow).contains("Fallow"))
        #expect(String(localized: AboutCopy.observatoryEdict).contains("Edict"))
    }

    @Test func aboutTitleResolvesToItsEnglishDefault() {
        #expect(String(localized: AboutCopy.aboutTitle) == "About")
    }
}
