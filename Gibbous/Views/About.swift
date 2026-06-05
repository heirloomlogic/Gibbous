//
//  About.swift
//  Gibbous
//
//  Credits, per the legal guardrails — names the originals and AstronomyKit,
//  uses our own copy (no lines from the original program).
//

import SwiftUI

struct About: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Gibbous")
                .font(.title2.weight(.semibold))
            Text("A charming tear-off moon companion for the Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Divider().frame(width: 200)
            Text(
                "A homage to Moontool by John Walker (1988) and the Macintosh "
                + "Moon Tool by Richard Knuckey. Built on AstronomyKit."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 320)
    }
}
