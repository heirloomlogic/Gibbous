import AppKit
import ImageIO
import SwiftUI
import Testing

@testable import Gibbous

@MainActor
struct SnapshotTests {
    static let outDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "gibbous_snapshots", isDirectory: true)

    /// A store wired with stub effects and (optionally) a seeded readout. Used
    /// to drive the composed view tree without touching live preferences.
    private func makeStore(withReadout: Bool) throws -> AppStore {
        let env = AppEnvironment(
            keyValue: InMemoryKeyValueStore(),
            timeZone: .current,
            now: { Date() },
            computeReadout: { date, tz, _ in try MoonAlmanac.readout(at: date, timeZone: tz) },
            playHowl: {},
            playHoot: {},
            setLoginItemEnabled: { _ in },
            loginItemEnabled: { false }
        )
        let store = AppStore.configured(environment: env)
        if withReadout {
            store.send(.readoutUpdated(try MoonAlmanac.readout(at: Date(), timeZone: .current)))
        }
        return store
    }

    /// Render the composed `CompanionView` for every skin in the given state and
    /// assert each came back non-blank (also writes reference PNGs to the temp
    /// dir for the verification checklist). Requires a GPU.
    private func snapshotEverySkin(
        prefix: String, withReadout: Bool, showingSettings: Bool = false
    ) throws {
        try FileManager.default.createDirectory(at: Self.outDir, withIntermediateDirectories: true)
        RetroFont.registerBundledFonts()
        let store = try makeStore(withReadout: withReadout)
        store.send(.setShowingSettings(showingSettings))

        for style in DisplayStyle.allCases {
            store.send(.setDisplayStyle(style))
            let image = snapshot(CompanionView().environment(store), name: "\(prefix)-\(style.rawValue).png")
            #expect((image?.width ?? 0) > 100, "\(style.rawValue) \(prefix) rendered blank")
        }
    }

    // A smoke test for the composed view pipeline in its default front face.
    @Test func snapshotBothPersonalities() throws {
        try snapshotEverySkin(prefix: "personality", withReadout: true)
    }

    // The settings/about back face for both skins — exercises SettingsPane and
    // its System-7 controls, which the front-face snapshot never reaches.
    @Test func snapshotSettingsFaceForBothPersonalities() throws {
        try snapshotEverySkin(prefix: "settings", withReadout: true, showingSettings: true)
    }

    // The "ephemeris unavailable" branch of both front faces (no readout set).
    @Test func snapshotUnavailableStateForBothPersonalities() throws {
        try snapshotEverySkin(prefix: "unavailable", withReadout: false)
    }

    @discardableResult
    private func snapshot(_ view: some View, name: String) -> CGImage? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(
            contentRect: hosting.frame, styleMask: [.borderless],
            backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))  // let the Metal disc render

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let cg = rep.cgImage else { return nil }
        let url = Self.outDir.appendingPathComponent(name)
        if let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, cg, nil)
            CGImageDestinationFinalize(dest)
        }
        return cg
    }
}
