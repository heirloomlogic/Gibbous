//
//  ModernView.swift
//  Gibbous
//
//  The 2026 skin: a clean dark dashboard with a hero moon and monospaced-digit
//  readouts.
//

import SwiftUI

private enum ModernTheme {
    static let background = Color(red: 0.055, green: 0.055, blue: 0.07)
    static let card = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let primary = Color(white: 0.96)
    static let secondary = Color(white: 0.62)
    static let hairline = Color(white: 1, opacity: 0.06)
}

struct ModernView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(ModernTheme.hairline)
            stats
        }
        .frame(width: 300)
        .background(ModernTheme.background)
        .foregroundStyle(ModernTheme.primary)
    }

    @ViewBuilder private var header: some View {
        if let readout = store.readout {
            HStack(spacing: 16) {
                MoonDiscView(request: MoonRenderRequest(readout: readout, style: .modern))
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(readout.phaseName).font(.headline)
                    Text("\(readout.illuminationText) lit")
                        .font(.subheadline).foregroundStyle(ModernTheme.secondary)
                    Text(readout.localTimeText)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .padding(.top, 2)
                }
                Spacer()
            }
            .padding(16)
        } else {
            MoonUnavailableView().frame(maxWidth: .infinity, minHeight: 128)
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
            Text(title).font(.callout).foregroundStyle(ModernTheme.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                if let secondary {
                    Text(secondary).foregroundStyle(ModernTheme.secondary)
                }
            }
            .font(.system(.callout, design: .rounded).monospacedDigit())
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
    }
}
