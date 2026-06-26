//
//  SnapshotModeTests.swift
//  GibbousTests
//
//  Pins the debug screenshot harness: the curated default instant must read as a
//  waxing gibbous Moon (the app's namesake, and the issue's headline
//  requirement), the environment flags parse as documented, and snapshot mode
//  freezes the clock only when actually active.
//

import Foundation
import Testing

@testable import Gibbous

struct SnapshotModeTests {
    // The headline requirement of issue #34: the locked moment shows a waxing
    // gibbous Moon. Run the curated default through the real ephemeris and assert
    // the visual phase, so the date can never silently drift off the requirement.
    @Test func curatedDefaultDateIsAWaxingGibbous() throws {
        let readout = try MoonAlmanac.readout(at: SnapshotMode.defaultDate, timeZone: .gmt)
        let phase = MoonPhaseDescriptor.current(
            illuminatedFraction: readout.illuminatedFraction, isWaxing: readout.isWaxing)
        #expect(phase == .waxingGibbous)
        #expect(readout.isWaxing)
        #expect(readout.illuminatedFraction > 0.55)
        #expect(readout.illuminatedFraction < 0.95)
    }

    @Test func isActiveOnlyForExactlyOne() {
        #expect(SnapshotMode.isActive(["GIBBOUS_SNAPSHOT": "1"]))
        #expect(!SnapshotMode.isActive(["GIBBOUS_SNAPSHOT": "0"]))
        #expect(!SnapshotMode.isActive(["GIBBOUS_SNAPSHOT": "true"]))
        #expect(!SnapshotMode.isActive([:]))
    }

    @Test func lockedDateHonorsValidOverride() {
        let override = "2014-10-08T10:55:00Z"  // the 2014 total-eclipse full moon
        let expected = ISO8601DateFormatter().date(from: override)
        #expect(SnapshotMode.lockedDate(["GIBBOUS_SNAPSHOT_DATE": override]) == expected)
    }

    @Test func lockedDateFallsBackOnMissingOrGarbageOverride() {
        #expect(SnapshotMode.lockedDate([:]) == SnapshotMode.defaultDate)
        #expect(SnapshotMode.lockedDate(["GIBBOUS_SNAPSHOT_DATE": "not-a-date"]) == SnapshotMode.defaultDate)
    }

    @Test func environmentFreezesNowWhenActive() {
        let env = SnapshotMode.environment(.live(), ["GIBBOUS_SNAPSHOT": "1"])
        #expect(env.now() == SnapshotMode.defaultDate)
        #expect(env.now() == env.now())  // frozen: every read is the same instant
    }

    @Test func environmentLeavesNowUntouchedWhenInactive() {
        let before = Date()
        let env = SnapshotMode.environment(.live(), [:])
        let sampled = env.now()
        #expect(sampled >= before)  // still the live wall clock, not the frozen date
        #expect(sampled != SnapshotMode.defaultDate)
    }
}
