//
//  CardCrossfadeTests.swift
//  GibbousTests
//
//  The cross-fade's animatable state: `flipped` seeds progress at the right
//  endpoint, and `animatableData` is the value SwiftUI interpolates as the card
//  turns over. The visual layering is exercised by the snapshot tests.
//

import SwiftUI
import Testing

@testable import Gibbous

@MainActor
struct CardCrossfadeTests {
    private func card(flipped: Bool) -> CardCrossfade<Text, Text> {
        CardCrossfade(flipped: flipped) {
            Text("front")
        } back: {
            Text("back")
        }
    }

    @Test func flippedSeedsProgressAtTheBackEndpoint() {
        #expect(card(flipped: true).animatableData == 1)
    }

    @Test func unflippedSeedsProgressAtTheFrontEndpoint() {
        #expect(card(flipped: false).animatableData == 0)
    }

    @Test func animatableDataIsReadWriteForInterpolation() {
        var card = card(flipped: false)
        card.animatableData = 0.5
        #expect(card.animatableData == 0.5)
    }
}
