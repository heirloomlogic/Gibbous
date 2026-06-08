//
//  About.swift
//  Gibbous
//
//  Credits, per the legal guardrails — names the originals and AstronomyKit,
//  uses our own copy (no lines from the original program). Closes with a quiet
//  nod to the apps that share Gibbous's sky — the one discoverable door to the
//  rest of Heirloom Logic. An invitation, never a nag.
//

import SwiftUI

struct About: View {
    private let heirloomLogic = URL(string: "https://github.com/heirloomlogic")

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Gibbous")
                .font(.title2.weight(.semibold))
            Text("A charming menu-bar moon companion for the Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Divider().frame(width: 200)
            Text(
                """
                A homage to Moontool by John Walker (1988) and the Macintosh \
                Moon Tool by Richard Knuckey. Built on AstronomyKit.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            observatory
        }
        .padding(28)
        .frame(width: 320)
    }

    /// The same sky, taken further — a soft pointer to Heirloom Logic's apps.
    /// Pre-launch, so this names them and links the maker, not a store page.
    private var observatory: some View {
        VStack(spacing: 8) {
            Divider().frame(width: 200)
            Text("FROM THE SAME OBSERVATORY")
                .font(.caption2.weight(.medium))
                .tracking(0.75)
                .foregroundStyle(.tertiary)
            Text(
                """
                Fallow, a celestial almanac for lunar practice, and Edict, an \
                observatory for timing what matters — both read from the same sky.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            if let heirloomLogic {
                Link("Coming from Heirloom Logic", destination: heirloomLogic)
                    .font(.footnote.weight(.medium))
            }
        }
    }
}
