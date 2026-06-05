import AppKit
import SwiftUI
import ImageIO
import Testing
@testable import Gibbous

@MainActor
struct SnapshotTests {
    static let outDir = FileManager.default.temporaryDirectory.appendingPathComponent("gibbous_spike", isDirectory: true)

    // A smoke test for the composed view pipeline (also writes reference PNGs
    // to the temp dir for the verification checklist). Requires a GPU.
    @Test func snapshotFourPersonalities() throws {
        try FileManager.default.createDirectory(at: Self.outDir, withIntermediateDirectories: true)
        RetroFont.registerBundledFonts()

        let env = AppEnvironment(
            keyValue: InMemoryKeyValueStore(), timeZone: .current,
            now: { Date() },
            computeReadout: { try MoonAlmanac.readout(at: $0, timeZone: $1) },
            playHowl: {})
        let store = AppStore.configured(environment: env)
        store.send(.readoutUpdated(try MoonAlmanac.readout(at: Date(), timeZone: .current)))

        let combos: [(String, DisplayStyle, Density)] = [
            ("modern-stats", .modern, .stats),
            ("modern-moononly", .modern, .moonOnly),
            ("retro-stats", .retro, .stats),
            ("retro-moononly", .retro, .moonOnly),
        ]
        for (name, style, density) in combos {
            store.send(.setDisplayStyle(style))
            store.send(.setDensity(density))
            let image = snapshot(CompanionView().environment(store), name: "personality-\(name).png")
            #expect(image != nil && image!.width > 100, "\(name) rendered blank")
        }
    }

    @discardableResult
    private func snapshot(_ view: some View, name: String) -> CGImage? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))   // let the Metal disc render

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
