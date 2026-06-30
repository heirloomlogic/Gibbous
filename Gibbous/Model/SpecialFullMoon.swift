//
//  SpecialFullMoon.swift
//  Gibbous
//
//  The handful of full moons that carry a *formal*, astronomically computable
//  name — the ones whose definition is geometry or the calendar, not folklore.
//  (The folk month-names — Strawberry, Wolf, Harvest-as-September — are a
//  Northern-Hemisphere lookup table with no single authority, so they're left
//  out.) The classification itself lives in `MoonAlmanac`, which has the
//  ephemeris; this is the pure result type and its display name.
//

import Foundation

/// A formally definable special full moon. A given full moon may satisfy more
/// than one of these (a blue moon can also be a supermoon); the headline shows
/// just the most notable, and **declaration order is that priority** — the rarer,
/// more remarked-upon names win over the common ones.
nonisolated enum SpecialFullMoonKind: CaseIterable, Equatable, Sendable {
    /// The second full moon in a calendar month (the popular, monthly definition).
    case blueMoon
    /// The full moon nearest the (Northern-Hemisphere) September equinox.
    case harvestMoon
    /// The full moon immediately after the Harvest moon.
    case huntersMoon
    /// A full moon near perigee — closer, and so larger, than usual.
    case supermoon

    /// The most notable kind among `kinds`, by declaration-order priority, or
    /// `nil` if none apply. Used to pick the single qualifier for the headline.
    static func mostNotable(in kinds: [SpecialFullMoonKind]) -> SpecialFullMoonKind? {
        allCases.first(where: kinds.contains)
    }

    /// The localized noun shown in the headline, e.g. "Blue Moon". Capitalized as
    /// a proper name so it reads as a label in "Full Moon (Blue Moon)".
    var name: LocalizedStringResource {
        switch self {
        case .blueMoon:
            return LocalizedStringResource(
                "special.blueMoon", defaultValue: "Blue Moon",
                comment: "Full-moon qualifier: the second full moon in a calendar month.")
        case .harvestMoon:
            return LocalizedStringResource(
                "special.harvestMoon", defaultValue: "Harvest Moon",
                comment: "Full-moon qualifier: the full moon nearest the September equinox.")
        case .huntersMoon:
            return LocalizedStringResource(
                "special.huntersMoon", defaultValue: "Hunter's Moon",
                comment: "Full-moon qualifier: the full moon just after the Harvest moon.")
        case .supermoon:
            return LocalizedStringResource(
                "special.supermoon", defaultValue: "Supermoon",
                comment: "Full-moon qualifier: a full moon near perigee, appearing larger than usual.")
        }
    }
}
