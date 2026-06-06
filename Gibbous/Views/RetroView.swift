//
//  RetroView.swift
//  Gibbous
//
//  The 1988 skin: a System-7 window with beveled group boxes, the public-domain
//  Chicago (ChicagoFLF) bitmap face, and the 1-bit dithered moon. A homage to
//  Moon Tool's layout, redrawn from our own ephemeris and our own disc.
//

import SwiftUI

enum RetroTheme {
    static let window = Color(white: 0.86)
    static let ink = Color.black
    static let sky = Color.black
    static let highlight = Color.white
    static let shadow = Color(white: 0.5)

    /// Chicago-style face — Robin Casady's public-domain ChicagoFLF, a revival
    /// of Susan Kare's System-7 Chicago. Bundled in Resources/Fonts and
    /// registered at launch; falls back to the system font if unavailable.
    static func font(_ size: CGFloat) -> Font { .custom("ChicagoFLF", size: size) }
}

struct RetroView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RetroGroupBox(title: "Moon") {
                moonDisc.frame(width: 150, height: 150)
            }
            .frame(width: 178)

            if let r = store.readout {
                VStack(spacing: 12) {
                    RetroGroupBox(title: "Phases of the Moon") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(r.phaseEvents) { event in
                                retroLine(event.label, r.eventText(event.date))
                            }
                        }
                    }
                    RetroGroupBox(title: "Moon Age") {
                        VStack(alignment: .leading, spacing: 4) {
                            retroLine("Age", r.moonAgeText)
                            retroLine("Lunation", r.lunationText)
                            retroLine("Julian", r.julianDateText)
                        }
                    }
                    RetroGroupBox(title: "Distance & Subtend") {
                        VStack(alignment: .leading, spacing: 4) {
                            retroLine("Moon", r.moonDistanceEarthRadiiText)
                            retroLine("Sun", r.sunDistanceAUText)
                            retroLine("Moon ∅", r.moonSubtendText)
                            retroLine("Sun ∅", r.sunSubtendText)
                        }
                    }
                    RetroGroupBox(title: "Time and Date") {
                        retroLine(r.localDateText, r.localTimeText)
                    }
                }
                .frame(width: 320)
            }
        }
        .padding(14)
        .background(RetroTheme.window)
        .foregroundStyle(RetroTheme.ink)
    }

    private var moonDisc: some View {
        Group {
            if let readout = store.readout {
                MoonDiscView(request: MoonRenderRequest(readout: readout, style: .retro, ditherCell: 1))
                    .background(RetroTheme.sky)
            } else {
                MoonUnavailableView()
            }
        }
    }

    private func retroLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer(minLength: 8)
            Text(value)
        }
        .font(RetroTheme.font(11))
        .lineLimit(1)
    }
}

/// A titled System-7 bevel frame: black outer rule with a white/gray inner
/// bevel, and the title notched into the top edge.
struct RetroGroupBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Rectangle().fill(RetroTheme.window)
                    Rectangle().stroke(RetroTheme.highlight, lineWidth: 1).offset(x: 1, y: 1)
                    Rectangle().stroke(RetroTheme.shadow, lineWidth: 1).offset(x: -1, y: -1)
                    Rectangle().stroke(RetroTheme.ink, lineWidth: 1)
                }
            )
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(RetroTheme.font(11))
                    .padding(.horizontal, 4)
                    .background(RetroTheme.window)
                    .offset(x: 12, y: -7)
            }
            .padding(.top, 9)  // room above the frame for the notched title
    }
}
