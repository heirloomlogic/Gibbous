//
//  CardCrossfade.swift
//  Gibbous
//
//  A two-sided card that cross-fades with depth to reveal its back. Only the
//  face currently toward the viewer is in the layout, so the container sizes to
//  that face and the swap happens at the half-way point — exactly when both
//  faces are at their lowest opacity. That midpoint swap is what lets the
//  popover resize cleanly between faces of different sizes (a 300pt Modern card,
//  a ~600pt Retro ledger, and their settings backs) while the resize hides
//  inside the dissolve.
//
//  This replaces an earlier 3D card flip: an NSPopover draws its own chrome and
//  arrow that can't rotate with the content, so a tumbling card inside a static
//  frame read as uncanny. A flat fade + subtle scale keeps the depth cue without
//  fighting the window.
//

import SwiftUI

struct CardCrossfade<Front: View, Back: View>: View, Animatable {
    private let front: Front
    private let back: Back

    /// 0 shows the front, 1 shows the back; SwiftUI interpolates as it toggles.
    private var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// How far each face recedes at the dissolve's midpoint.
    private let depth = 0.04

    init(flipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
        self.progress = flipped ? 1 : 0
    }

    var body: some View {
        Group {
            if progress < 0.5 {
                let t = progress * 2  // 0 → 1 across the first half
                front
                    .opacity(1 - t)
                    .scaleEffect(1 - depth * t)  // 1.0 → recedes
            } else {
                let t = (progress - 0.5) * 2  // 0 → 1 across the second half
                back
                    .opacity(t)
                    .scaleEffect(1 - depth * (1 - t))  // comes forward → 1.0
            }
        }
    }
}

#if DEBUG
#Preview("Card crossfade — front") {
    CardCrossfade(flipped: false) {
        Text(verbatim: "Front").frame(width: 220, height: 130).background(.blue.opacity(0.2))
    } back: {
        Text(verbatim: "Back").frame(width: 260, height: 180).background(.green.opacity(0.2))
    }
    .padding()
}
#endif
