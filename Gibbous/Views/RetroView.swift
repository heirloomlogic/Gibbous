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

    /// Dimmed ink for ledger labels and secondary readouts.
    var muted: Color { ink.opacity(0.55) }

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

    /// Widths for the hero-left / ledger-right composition. The moon disc anchors
    /// the left column and sets its height; the right column stacks the data boxes
    /// to roughly match it, and the Time-and-Date footer spans both.
    private enum Layout {
        static let gap: CGFloat = 12
        static let disc: CGFloat = 208
        static let heroBox: CGFloat = disc + 24  // disc + 12pt content padding each side
        static let rightCol: CGFloat = 332

        static let total: CGFloat = heroBox + gap + rightCol
        /// A half of the right column, for the paired Age | Subtend boxes.
        static let halfRight: CGFloat = (rightCol - gap) / 2
    }

    var body: some View {
        Group {
            if let r = store.readout {
                layout(r)
            } else {
                hero(nil)
            }
        }
        .padding(14)
        .foregroundStyle(palette.ink)
    }

    /// Hero moon on the left; a ledger of data boxes on the right; a full-width
    /// Time-and-Date footer beneath both.
    private func layout(_ r: MoonReadout) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .top, spacing: Layout.gap) {
                hero(r)
                VStack(spacing: Layout.gap) {
                    RetroGroupBox(title: ReadoutCopy.phasesTitle) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(r.phaseEvents) { event in
                                retroLine(event.label, r.eventText(event.date))
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: Layout.gap) {
                        RetroGroupBox(title: ReadoutCopy.moonAgeTitle) {
                            VStack(alignment: .leading, spacing: 4) {
                                retroLine(ReadoutCopy.age, r.moonAgeText)
                                retroLine(ReadoutCopy.lunation, r.lunationText)
                            }
                        }
                        .frame(width: Layout.halfRight)
                        RetroGroupBox(title: ReadoutCopy.subtendTitle) {
                            VStack(alignment: .leading, spacing: 4) {
                                retroLine(ReadoutCopy.moonSubtend, r.moonSubtendText)
                                retroLine(ReadoutCopy.sunSubtend, r.sunSubtendText)
                            }
                        }
                        .frame(width: Layout.halfRight)
                    }
                    RetroGroupBox(title: ReadoutCopy.distanceTitle) {
                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 4) {
                            distanceRow(ReadoutCopy.moon, r.moonDistanceText, r.moonDistanceEarthRadiiText)
                            distanceRow(ReadoutCopy.sun, r.sunDistanceText, r.sunDistanceAUText)
                        }
                    }
                }
                .frame(width: Layout.rightCol)
            }
            RetroGroupBox(title: ReadoutCopy.timeAndDateTitle) {
                HStack(spacing: 8) {
                    Text(r.localDateText)
                    Spacer(minLength: 8)
                    Text(r.julianDateCaption)
                        .foregroundStyle(palette.muted)
                    Spacer(minLength: 8)
                    Text(r.localTimeText)
                }
                .font(RetroTheme.font(11))
                .lineLimit(1)
            }
            .frame(width: Layout.total)
        }
    }

    /// The hero: the dithered disc with the current phase name and illumination
    /// beneath it — the readout's headline, which the disc alone can't spell out.
    private func hero(_ r: MoonReadout?) -> some View {
        RetroGroupBox(title: ReadoutCopy.moon, fill: true) {
            VStack(spacing: 8) {
                moonDisc(r).frame(width: Layout.disc, height: Layout.disc)
                if let r {
                    VStack(spacing: 2) {
                        Text(r.phaseHeadline)
                            .font(RetroTheme.font(14))
                        Text(r.illuminationCaption)
                            .font(RetroTheme.font(11))
                            .foregroundStyle(palette.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: Layout.heroBox)
        .frame(maxHeight: .infinity)
    }

    private func moonDisc(_ r: MoonReadout?) -> some View {
        Group {
            if let r {
                // Transparent outside the disc, so the popover's glass shows
                // through behind the dithered moon.
                MoonDiscView(request: MoonRenderRequest(readout: r, style: .retro, ditherCell: 1))
            } else {
                MoonUnavailableView()
            }
        }
    }

    /// A ledger line: a dimmed label on the left, the value spread to the box's
    /// right edge. Distance uses `distanceRow` for its aligned unit columns.
    private func retroLine(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).foregroundStyle(palette.ink.opacity(0.55))
            Spacer(minLength: 8)
            Text(value)
        }
        .font(RetroTheme.font(11))
        .lineLimit(1)
    }

    /// A Distance row in the two-unit layout: a dimmed label on the left, then the
    /// km value and the secondary unit (ER / AU) right-aligned into shared columns,
    /// the way Moon Tool tabulates distance.
    private func distanceRow(_ label: LocalizedStringResource, _ primary: String, _ secondary: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(palette.ink.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(primary)
            Text(secondary)
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
    let title: LocalizedStringResource
    /// When true, the framed area stretches to fill the available height (its
    /// content stays top-anchored). Used by the hero so its frame bottom lines
    /// up with the taller data column beside it.
    var fill: Bool = false
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
                .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
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

#if DEBUG
#Preview("Retro") {
    RetroView().environment(AppStore.preview(style: .retro))
}

#Preview("Retro — unavailable") {
    RetroView().environment(AppStore.preview(style: .retro, readout: nil))
}
#endif
