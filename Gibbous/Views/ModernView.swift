//
//  ModernView.swift
//  Gibbous
//
//  The 2026 skin: a hero-left / ledger-right dashboard that mirrors Retro's
//  information architecture in Liquid Glass. A large disc anchors the left
//  column; the data sits in labelled glass ledgers on the right; a full-width
//  Time-and-Date bar spans both. Surfaces are Liquid Glass over the popover's
//  own glass, so the look follows the system light/dark appearance instead of a
//  fixed palette.
//

import SwiftUI

struct ModernView: View {
    @Environment(AppStore.self) private var store
    @Namespace private var glass

    /// Widths for the hero-left / ledger-right composition, sized so the disc
    /// matches Retro's 208pt moon and the overall footprint sits close to Retro's.
    /// The hero stretches to the (taller) right column's height, floating the moon
    /// centred in its glass.
    private enum Layout {
        static let gap: CGFloat = 12
        static let disc: CGFloat = 208
        static let hero: CGFloat = disc + 32  // disc + 16pt content padding each side
        static let rightCol: CGFloat = 320
        static let total: CGFloat = hero + gap + rightCol
        /// A half of the right column, for the paired Moon Age | Subtend ledgers.
        static let half: CGFloat = (rightCol - gap) / 2
    }

    var body: some View {
        Group {
            if let r = store.readout {
                content(r)
            } else {
                unavailable
            }
        }
        .frame(width: Layout.total)
        .padding(12)
        .foregroundStyle(.primary)
    }

    private func content(_ r: MoonReadout) -> some View {
        VStack(spacing: Layout.gap) {
            HStack(alignment: .top, spacing: Layout.gap) {
                section(ReadoutCopy.moon) { hero(r) }
                rightColumn(r)
            }
            footer(r)
        }
    }

    // MARK: Hero

    /// The disc and its card share a glass container so the disc reads as a lens
    /// on the card glass; stable IDs keep the two from re-flowing into each other
    /// on resize (the per-minute readout update, the cross-fade to settings). The
    /// ledgers and footer are standalone surfaces — outside any container they
    /// can't merge with their neighbours, which is what stops the goopy morph.
    private func hero(_ r: MoonReadout) -> some View {
        GlassStack(spacing: 12) {
            VStack(spacing: 12) {
                MoonDiscView(request: MoonRenderRequest(readout: r, style: .modern))
                    .frame(width: Layout.disc, height: Layout.disc)
                    .glassSurface(in: .circle, id: "disc", namespace: glass)
                VStack(spacing: 4) {
                    Text(r.phaseName).font(.title3.weight(.semibold))
                    Text(r.illuminationCaption)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassSurface(in: .rect(cornerRadius: 20), id: "header", namespace: glass)
        }
        .frame(width: Layout.hero)
        .frame(maxHeight: .infinity)
    }

    // MARK: Right column

    private func rightColumn(_ r: MoonReadout) -> some View {
        VStack(spacing: Layout.gap) {
            section(ReadoutCopy.phasesTitle) {
                ledger {
                    ForEach(r.phaseEvents) { event in
                        StatRow(event.label, r.eventText(event.date))
                    }
                }
            }
            HStack(alignment: .top, spacing: Layout.gap) {
                section(ReadoutCopy.moonAgeTitle) {
                    ledger {
                        StatRow(ReadoutCopy.age, r.moonAgeText)
                        StatRow(ReadoutCopy.lunation, r.lunationText)
                    }
                }
                .frame(width: Layout.half)
                section(ReadoutCopy.subtendTitle) {
                    ledger {
                        StatRow(ReadoutCopy.moonSubtend, r.moonSubtendText)
                        StatRow(ReadoutCopy.sunSubtend, r.sunSubtendText)
                    }
                }
                .frame(width: Layout.half)
            }
            section(ReadoutCopy.distanceTitle) {
                ledger {
                    StatRow(ReadoutCopy.moon, r.moonDistanceText, secondary: r.moonDistanceEarthRadiiText)
                    StatRow(ReadoutCopy.sun, r.sunDistanceText, secondary: r.sunDistanceAUText)
                }
            }
        }
        .frame(width: Layout.rightCol)
    }

    // MARK: Footer

    /// A full-width bar carrying the date, Julian date, and the running clock —
    /// Modern's take on Retro's Time-and-Date footer.
    private func footer(_ r: MoonReadout) -> some View {
        HStack(spacing: 12) {
            Text(r.localDateText)
            Spacer(minLength: 8)
            Text(r.julianDateCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(r.localTimeText)
        }
        .font(.system(.callout, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassSurface(in: .rect(cornerRadius: 16))
    }

    // MARK: Building blocks

    /// A titled group: a small all-caps label above a glass ledger. The label band
    /// also clears the top-right ⓘ that flips the card to settings.
    private func section<Content: View>(
        _ title: LocalizedStringResource, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content()
        }
    }

    private func ledger<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 6)
            .glassSurface(in: .rect(cornerRadius: 16))
    }

    @ViewBuilder private var unavailable: some View {
        MoonUnavailableView()
            .frame(maxWidth: .infinity, minHeight: 200)
            .glassSurface(in: .rect(cornerRadius: 20))
    }
}

private struct StatRow: View {
    let title: LocalizedStringResource
    let value: String
    var secondary: String?

    init(_ title: LocalizedStringResource, _ value: String, secondary: String? = nil) {
        self.title = title
        self.value = value
        self.secondary = secondary
    }

    var body: some View {
        HStack {
            Text(title).font(.callout).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                if let secondary {
                    Text(secondary).foregroundStyle(.secondary)
                }
            }
            .font(.system(.callout, design: .monospaced))
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
    }
}

#if DEBUG
#Preview("Modern") {
    ModernView().environment(AppStore.preview(style: .modern))
}

#Preview("Modern — unavailable") {
    ModernView().environment(AppStore.preview(style: .modern, readout: nil))
}
#endif
