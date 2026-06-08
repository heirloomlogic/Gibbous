//
//  RetroView.swift
//  Gibbous
//
//  The 1988 skin: a System-7 window with beveled group boxes, the public-domain
//  Chicago (ChicagoFLF) bitmap face, and the 1-bit dithered moon. A homage to
//  Moon Tool's layout, redrawn from our own ephemeris and our own disc.
//
//  The bevel palette is resolved from the system appearance: classic light-gray
//  System 7 in light mode, and an inverted "dark System 7" in dark mode. The
//  window has no fixed background — the group boxes float on the popover's
//  Liquid Glass.
//

import SwiftUI

/// System-7 frame palette, resolved per appearance: `ink` is the engraved rule
/// and the text colour, `highlight` the faint inner bevel. Light mode is the
/// classic black-on-gray look; dark mode inverts to light ink on the dark glass.
struct RetroPalette {
    let ink: Color
    let highlight: Color

    static func resolve(_ scheme: ColorScheme) -> RetroPalette {
        switch scheme {
        case .dark:
            return RetroPalette(ink: Color(white: 0.92), highlight: Color(white: 0.30))
        default:
            return RetroPalette(ink: .black, highlight: .white)
        }
    }
}

enum RetroTheme {
    /// Chicago-style face — Robin Casady's public-domain ChicagoFLF, a revival
    /// of Susan Kare's System-7 Chicago. Bundled in Resources/Fonts and
    /// registered at launch; falls back to the system font if unavailable.
    static func font(_ size: CGFloat) -> Font { .custom("ChicagoFLF", size: size) }
}

struct RetroView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

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
        .foregroundStyle(palette.ink)
    }

    private var moonDisc: some View {
        Group {
            if let readout = store.readout {
                // Transparent outside the disc, so the popover's glass shows
                // through behind the dithered moon.
                MoonDiscView(request: MoonRenderRequest(readout: readout, style: .retro, ditherCell: 1))
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

/// A titled System-7 section: a bold Chicago label above an unfilled beveled
/// frame. There is no fill — the popover's own Liquid Glass shows through the
/// frame and behind the content; only the 1px engraved rule and a faint inner
/// highlight (resolved per appearance) draw the System-7 outline.
struct RetroGroupBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme
    private var palette: RetroPalette { RetroPalette.resolve(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(RetroTheme.font(11))
                .foregroundStyle(palette.ink)
                .padding(.leading, 2)
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    ZStack {
                        Rectangle().strokeBorder(palette.highlight.opacity(0.5), lineWidth: 1)
                            .padding(1)
                        Rectangle().strokeBorder(palette.ink, lineWidth: 1)
                    }
                }
        }
    }
}
