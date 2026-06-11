//
//  CardFlip.swift
//  Gibbous
//
//  A two-sided card that turns over in 3D to reveal its back. Only the face
//  currently toward the viewer is in the layout, so the container sizes to that
//  face and the swap happens at the 90° edge-on midpoint — exactly when the
//  size change is invisible. That midpoint swap is what lets the popover resize
//  cleanly between faces of different sizes (a 300pt Modern card, a ~600pt Retro
//  ledger, and their settings backs).
//

import SwiftUI

struct CardFlip<Front: View, Back: View>: View, Animatable {
    private let front: Front
    private let back: Back

    /// The live turn angle, interpolated by SwiftUI as `flipped` toggles.
    private var rotation: Double
    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    init(flipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
        self.rotation = flipped ? 180 : 0
    }

    var body: some View {
        Group {
            if rotation < 90 {
                front
            } else {
                // Pre-flip the back so the outer rotation lands it upright (not
                // mirrored) once the card has turned past edge-on.
                back.rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            }
        }
        .rotation3DEffect(.degrees(rotation), axis: (0, 1, 0))
    }
}
