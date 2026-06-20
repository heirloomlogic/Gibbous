//
//  DisplayStyleTests.swift
//  GibbousTests
//
//  The look axis: its skin labels (Modern shows the live calendar year, Retro
//  the fixed "1988"), its case set, and Codable round-tripping (the form the
//  preference is persisted in).
//

import Foundation
import Testing

@testable import Gibbous

struct DisplayStyleTests {
    @Test func modernLabelIsTheCurrentCalendarYear() {
        let year = String(Calendar.current.component(.year, from: Date()))
        #expect(DisplayStyle.modern.displayName == year)
    }

    @Test func retroLabelIsNineteenEightyEight() {
        #expect(DisplayStyle.retro.displayName == "1988")
    }

    @Test func bothSkinsAreEnumerated() {
        #expect(DisplayStyle.allCases == [.modern, .retro])
    }

    @Test func rawValuesAreTheStablePersistenceTokens() {
        #expect(DisplayStyle.modern.rawValue == "modern")
        #expect(DisplayStyle.retro.rawValue == "retro")
    }

    @Test(arguments: DisplayStyle.allCases)
    func codableRoundTrips(_ style: DisplayStyle) throws {
        let data = try JSONEncoder().encode(style)
        #expect(try JSONDecoder().decode(DisplayStyle.self, from: data) == style)
    }
}
