//
//  ModernView.swift
//  Gibbous
//
//  The 2026 skin: a clean dashboard with a hero moon and monospaced-digit
//  readouts. Surfaces are Liquid Glass over the popover's own glass, so the
//  look follows the system light/dark appearance instead of a fixed palette.
//

import SwiftUI

struct ModernView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        GlassStack(spacing: 12) {
            VStack(spacing: 12) {
                header
                stats
            }
            .padding(12)
        }
        .frame(width: 300)
        .foregroundStyle(.primary)
    }

    @ViewBuilder private var header: some View {
        if let readout = store.readout {
            HStack(spacing: 16) {
                MoonDiscView(request: MoonRenderRequest(readout: readout, style: .modern))
                    .frame(width: 96, height: 96)
                    .glassSurface(in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(readout.phaseName).font(.headline)
                    Text("\(readout.illuminationText) lit")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(readout.localTimeText)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .padding(.top, 2)
                }
                Spacer()
            }
            .padding(16)
            .glassSurface(in: .rect(cornerRadius: 16))
        } else {
            MoonUnavailableView()
                .frame(maxWidth: .infinity, minHeight: 128)
                .glassSurface(in: .rect(cornerRadius: 16))
        }
    }

    @ViewBuilder private var stats: some View {
        if let r = store.readout {
            VStack(spacing: 0) {
                StatRow("Moon age", r.moonAgeText)
                StatRow("Lunation", r.lunationText)
                StatRow("Julian date", r.julianDateText)
                StatRow("Moon distance", r.moonDistanceText, secondary: r.moonDistanceEarthRadiiText)
                StatRow("Sun distance", r.sunDistanceAUText)
                StatRow("Moon subtends", r.moonSubtendText)
                StatRow("Sun subtends", r.sunSubtendText)
                StatRow("Date", r.localDateText)
            }
            .padding(.vertical, 6)
            .glassSurface(in: .rect(cornerRadius: 16))
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String
    var secondary: String?

    init(_ title: String, _ value: String, secondary: String? = nil) {
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
            .font(.system(.callout, design: .rounded).monospacedDigit())
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
    }
}
